function main(modules, package)
    if package:is_plat("windows") then
        print(os.iorunv("ls"))
        local cmake_code = io.readfile("libs/nowide/CMakeLists.txt")
        cmake_code = cmake_code:gsub("def_WERROR ON", "def_WERROR OFF")
        io.writefile("libs/nowide/CMakeLists.txt", cmake_code)
    end

    local enabled_libraries = {}
    local configs = { "-DCMAKE_BUILD_TYPE=" .. (package:is_debug() and "Debug" or "Release"),
                      "-DBUILD_SHARED_LIBS=" .. (package:config("shared") and "ON" or "OFF") }
    for module, _ in pairs(modules) do
        local enabled = package:config("all") or package:config(module)
        if enabled then
            table.insert(enabled_libraries, module)
        end
        if libname == "python" then
            table.insert(configs, "-DBOOST_ENABLE_PYTHON=" .. (enabled and "ON" or "OFF"))
        elseif libname == "mpi" then
            table.insert(configs, "-DBOOST_ENABLE_MPI=" .. (enabled and "ON" or "OFF"))
        end     

        if module == "stacktrace" and enabled then
            table.insert(configs, "-DBOOST_STACKTRACE_ENABLE_NOOP=" .. (package:config("stacktrace_enable_noop") and "ON" or "OFF"))
            table.insert(configs, "-DBOOST_STACKTRACE_ENABLE_BACKTRACE=" .. (package:config("stacktrace_enable_backtrace") and "ON" or "OFF"))
            table.insert(configs, "-DBOOST_STACKTRACE_ENABLE_ADDR2LINE=" .. (package:config("stacktrace_enable_addr2line") and "ON" or "OFF"))
            table.insert(configs, "-DBOOST_STACKTRACE_ENABLE_BASIC=" .. (package:config("stacktrace_enable_basic") and "ON" or "OFF"))
        elseif module == "context" and enabled then
            local arch
            if package:is_arch("aarch64", "arm64+.*") or package:is_plat("iphoneos", "aarch64.*", "arm64.*") then
                arch = "arm64"
            elseif package:is_arch("arm+.*") or package:is_plat("arm.*") then
                arch = "arm"
            elseif package:is_arch("x64", "x86_64") then
                arch = "x86_64"
            elseif package:is_arch("i386", "x86") then
                arch = "i386"
            elseif package:is_arch("loongarch64") then
                arch = "loongarch64"
            elseif package:is_arch("mips64", "mipsel64") then
                arch = "mips64"
            elseif package:is_arch("mips", "mipsel") then
                arch = "mips32"
            elseif package:is_arch("ppc64") then
                arch = "ppc64"
            elseif package:is_arch("ppc") then
                arch = "ppc32"
            elseif package:is_arch("riscv64") then
                arch = "riscv64"
            end
            if arch then
                table.insert(configs, "-DBOOST_CONTEXT_ARCHITECTURE=" .. arch)
            end
        end
    end

    table.insert(configs, "-DBOOST_INCLUDE_LIBRARIES=" .. table.concat(enabled_libraries, ";"))

    import("package.tools.cmake").install(package, configs, {cmake_generator = "Ninja"})
end

