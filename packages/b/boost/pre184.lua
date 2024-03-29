function main(libnames, package)
    import("core.base.option")

    function get_compiler(package, toolchain)
        local cxx = package:build_getenv("cxx")
        if package:is_plat("macosx") then
            -- we uses ld/clang++ for link stdc++ for shared libraries
            -- and we need `xcrun -sdk macosx clang++` to make b2 to get `-isysroot` automatically
            local cc = package:build_getenv("ld")
            if cc and cc:find("clang", 1, true) and cc:find("Xcode", 1, true) then
                cc = "xcrun -sdk macosx clang++"
            end
            return format("using darwin : : %s ;", cc)
        elseif package:is_plat("windows") then
            local vs_toolset = toolchain:config("vs_toolset")
            local msvc_ver = ""
            local win_toolset = "msvc"
            if toolchain:name() == "clang-cl" then
                win_toolset = "clang-win"
                cxx = cxx:gsub("(clang%-cl)$", "%1.exe", 1)
                msvc_ver = ""
            elseif vs_toolset then
                local i = vs_toolset:find("%.")
                msvc_ver = i and vs_toolset:sub(1, i + 1)
            end

            -- Specifying a version will disable b2 from forcing tools
            -- from the latest installed msvc version.
            return format("using %s : %s : \"%s\" ;", win_toolset, msvc_ver, cxx:gsub("\\", "\\\\"))
        else
            cxx = cxx:gsub("gcc$", "g++")
            cxx = cxx:gsub("clang$", "clang++")
            return format("using gcc : : \"%s\" ;", cxx:gsub("\\", "/"))
        end
    end

    -- get host toolchain
    import("core.tool.toolchain")
    local host_toolchain
    if package:is_plat("windows") then
        host_toolchain = toolchain.load("msvc", {plat = "windows", arch = os.arch()})
        if not host_toolchain:check() then
            host_toolchain = toolchain.load("clang-cl", {plat = "windows", arch = os.arch()})
        end
        assert(host_toolchain:check(), "host msvc or clang-cl not found!")
    end

    -- force boost to compile with the desired compiler
    local file = io.open("user-config.jam", "w")
    if file then
        file:write(get_compiler(package, host_toolchain))
        file:close()
    end

    local bootstrap_argv =
    {
        "--prefix=" .. package:installdir(),
        "--libdir=" .. package:installdir("lib"),
        "--without-icu"
    }

    if package:has_tool("cxx", "clang", "clangxx") then
        table.insert(bootstrap_argv, "--with-toolset=clang")
    end

    if package:is_plat("windows") then
        -- for bootstrap.bat, all other arguments are useless
        bootstrap_argv = { "msvc" }
        os.vrunv("bootstrap.bat", bootstrap_argv, {envs = host_toolchain:runenvs()})
    elseif package:is_plat("mingw") and is_host("windows") then
        bootstrap_argv = { "gcc" }
        os.vrunv("bootstrap.bat", bootstrap_argv)
        -- todo looking for better solution to fix the confict between user-config.jam and project-config.jam
        io.replace("project-config.jam", "using[^\n]+", "")
    else
        os.vrunv("./bootstrap.sh", bootstrap_argv)
    end

    -- get build toolchain
    local build_toolchain
    local build_toolset
    local runenvs
    if package:is_plat("windows") then
        build_toolchain = package:toolchain("clang-cl") or package:toolchain("msvc") or
            toolchain.load("msvc", {plat = package:plat(), arch = package:arch()})
        assert(build_toolchain:check(), "build toolchain not found!")
        build_toolset = build_toolchain:name() == "clang-cl" and "clang-win" or "msvc"
        runenvs = build_toolchain:runenvs()
    end

    local file = io.open("user-config.jam", "w")
    if file then
        file:write(get_compiler(package, build_toolchain))
        file:close()
    end
    os.vrun("./b2 headers")

    local njobs = option.get("jobs") or tostring(os.default_njob())
    local argv =
    {
        "--prefix=" .. package:installdir(),
        "--libdir=" .. package:installdir("lib"),
        "-d2",
        "-j" .. njobs,
        "--hash",
        "-q", -- quit on first error
        "--layout=tagged-1.66", -- prevent -x64 suffix in case cmake can't find it
        "--user-config=user-config.jam",
        "-sNO_LZMA=1",
        "-sNO_ZSTD=1",
        "install",
        "threading=" .. (package:config("multi") and "multi" or "single"),
        "debug-symbols=" .. (package:debug() and "on" or "off"),
        "link=" .. (package:config("shared") and "shared" or "static"),
        "variant=" .. (package:is_debug() and "debug" or "release"),
        "runtime-debugging=" .. (package:is_debug() and "on" or "off")
    }

    if package:config("lto") then
        table.insert(argv, "lto=on")
    end
    if package:is_arch("aarch64", "arm+.*") then
        table.insert(argv, "architecture=arm")
    end
    if package:is_arch(".+64.*") then
        table.insert(argv, "address-model=64")
    else
        table.insert(argv, "address-model=32")
    end
    local cxxflags
    local linkflags
    if package:is_plat("windows") then
        local vs_runtime = package:config("vs_runtime")
        if package:config("shared") then
            table.insert(argv, "runtime-link=shared")
        elseif vs_runtime and vs_runtime:startswith("MT") then
            table.insert(argv, "runtime-link=static")
        else
            table.insert(argv, "runtime-link=shared")
        end
        table.insert(argv, "toolset=" .. build_toolset)
        cxxflags = "-std:c++14"
    elseif package:is_plat("mingw") then
        table.insert(argv, "toolset=gcc")
    elseif package:is_plat("macosx") then
        table.insert(argv, "toolset=darwin")

        -- fix macosx arm64 build issue https://github.com/microsoft/vcpkg/pull/18529
        cxxflags = "-std=c++14 -arch " .. package:arch()
        local xcode = package:toolchain("xcode") or import("core.tool.toolchain").load("xcode", {plat = package:plat(), arch = package:arch()})
        if xcode:check() then
            local xcode_dir = xcode:config("xcode")
            local xcode_sdkver = xcode:config("xcode_sdkver")
            local target_minver = xcode:config("target_minver")
            if xcode_dir and xcode_sdkver then
                local xcode_sdkdir = xcode_dir .. "/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX" .. xcode_sdkver .. ".sdk"
                cxxflags = cxxflags .. " -isysroot " .. xcode_sdkdir
            end
            if target_minver then
                cxxflags = cxxflags .. " -mmacosx-version-min=" .. target_minver
            end
        end
    else
        cxxflags = "-std=c++14"
        if package:config("pic") ~= false then
            cxxflags = cxxflags .. " -fPIC"
        end
    end
    if package.has_runtime and package:has_runtime("c++_shared", "c++_static") then
        cxxflags = (cxxflags or "") .. " -stdlib=libc++"
        linkflags = (linkflags or "") .. " -stdlib=libc++"
        if package:has_runtime("c++_static") then
            linkflags = linkflags .. " -static-libstdc++"
        end
    end
    if cxxflags then
        table.insert(argv, "cxxflags=" .. cxxflags)
    end
    if linkflags then
        table.insert(argv, "linkflags=" .. linkflags)
    end
    for _, libname in ipairs(libnames) do
        if package:config("all") or package:config(libname) then
            table.insert(argv, "--with-" .. libname)
        end
    end

    if package:is_plat("linux") then
        table.insert(argv, "pch=off")
    end

    local ok = os.execv("./b2", argv, {envs = runenvs, try = true, stdout = "boost-log.txt"})
    if ok ~= 0 then
        raise("boost build failed, please check log in " .. path.join(os.curdir(), "boost-log.txt"))
    end
end
