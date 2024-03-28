includes(path.join(os.scriptdir(), "gen/modules.lua"))

package("boost")

    set_homepage("https://www.boost.org/")
    set_description("Collection of portable C++ source libraries.")
    set_license("BSL-1.0")

    add_urls("https://github.com/boostorg/boost/releases/download/boost-$(version)/boost-$(version).tar.gz")
    add_urls("https://github.com/xmake-mirror/boost/releases/download/boost-$(version).tar.bz2", {alias = "mirror", version = function (version)
            return version .. "/boost_" .. (version:gsub("%.", "_"))
        end})

    add_versions("1.84.0", "4d27e9efed0f6f152dc28db6430b9d3dfb40c0345da7342eaa5a987dde57bd95")
    add_versions("1.83.0", "0c6049764e80aa32754acd7d4f179fd5551d8172a83b71532ae093e7384e98da")
    add_versions("1.82.0", "b62bd839ea6c28265af9a1f68393eda37fab3611425d3b28882d8e424535ec9d")
    add_versions("1.81.0", "121da556b718fd7bd700b5f2e734f8004f1cfa78b7d30145471c526ba75a151c")
    add_versions("mirror:1.80.0", "1e19565d82e43bc59209a168f5ac899d3ba471d55c7610c677d4ccf2c9c500c0")
    add_versions("mirror:1.79.0", "475d589d51a7f8b3ba2ba4eda022b170e562ca3b760ee922c146b6c65856ef39")
    add_versions("mirror:1.78.0", "8681f175d4bdb26c52222665793eef08490d7758529330f98d3b29dd0735bccc")
    add_versions("mirror:1.77.0", "fc9f85fc030e233142908241af7a846e60630aa7388de9a5fafb1f3a26840854")
    add_versions("mirror:1.76.0", "f0397ba6e982c4450f27bf32a2a83292aba035b827a5623a14636ea583318c41")
    add_versions("mirror:1.75.0", "953db31e016db7bb207f11432bef7df100516eeb746843fa0486a222e3fd49cb")
    add_versions("mirror:1.74.0", "83bfc1507731a0906e387fc28b7ef5417d591429e51e788417fe9ff025e116b1")
    add_versions("mirror:1.73.0", "4eb3b8d442b426dc35346235c8733b5ae35ba431690e38c6a8263dce9fcbb402")
    add_versions("mirror:1.72.0", "59c9b274bc451cf91a9ba1dd2c7fdcaf5d60b1b3aa83f2c9fa143417cc660722")
    add_versions("mirror:1.70.0", "430ae8354789de4fd19ee52f3b1f739e1fba576f0aded0897c3c2bc00fb38778")

    if is_plat("mingw") and is_subhost("msys") then
        add_extsources("pacman::boost")
    elseif is_plat("linux") then
        add_extsources("pacman::boost", "apt::libboost-all-dev")
    elseif is_plat("macosx") then
        add_extsources("brew::boost")
    end

    add_patches("1.75.0", path.join(os.scriptdir(), "patches", "1.75.0", "warning.patch"), "43ff97d338c78b5c3596877eed1adc39d59a000cf651d0bcc678cf6cd6d4ae2e")

    if is_plat("linux") then
        add_deps("bzip2", "zlib")
        add_syslinks("pthread", "dl")
    end

    add_configs("pyver", {description = "python version x.y, etc. 3.10", default = "3.10"})

    add_configs("all",          { description = "Enable all library modules support.",  default = true, type = "boolean"})
    add_configs("multi",        { description = "Enable multi-thread support.",  default = true, type = "boolean"})
    for module, _ in pairs(modules) do
        add_configs(module,    { description = "Enable " .. module .. " library.", default = (module == "core"), type = "boolean"})
    end

    add_configs("stacktrace_enable_noop", { description = "Enable noop backend of stacktrace", default = true, type = "boolean"})
    add_configs("stacktrace_enable_backtrace", { description = "Enable noop backend of stacktrace", default = false, type = "boolean"})
    add_configs("stacktrace_enable_addr2line", { description = "Enable noop backend of stacktrace", default = not is_plat("windows"), type = "boolean"})
    add_configs("stacktrace_enable_basic", { description = "Enable noop backend of stacktrace", default = true, type = "boolean"})

    local libnames = {"fiber",
                      "coroutine",
                      "context",
                      "regex",
                      "system",
                      "container",
                      "exception",
                      "timer",
                      "atomic",
                      "graph",
                      "serialization",
                      "random",
                      "wave",
                      "date_time",
                      "locale",
                      "iostreams",
                      "program_options",
                      "test",
                      "chrono",
                      "contract",
                      "graph_parallel",
                      "json",
                      "log",
                      "thread",
                      "filesystem",
                      "math",
                      "mpi",
                      "nowide",
                      "python",
                      "stacktrace",
                      "type_erasure"}

    on_load(function (package)
        -- disable auto-link all libs
        if package:is_plat("windows") then
            package:add("defines", "BOOST_ALL_NO_LIB")
        end

        if package:config("python") then
            if not package:config("shared") then
                package:add("defines", "BOOST_PYTHON_STATIC_LIB")
            end
            package:add("deps", "python " .. package:config("pyver") .. ".x", {configs = {headeronly = true}})
        end

        if package:config("stacktrace") then 
            if package:config("stacktrace_enable_backtrace") then
                package:add("deps", "libbacktrace")
            end
        end

        if package:is_plat("windows") then
            local cmake_code = io.readfile("boost/libs/nowide/CMakeLists.txt")
            cmake_code = cmake_code:gsub("def_WERROR ON", "def_WERROR OFF")
            io.writefile("boost/libs/nowide/CMakeLists.txt", cmake_code)
        end

        if not package:config("all") then
            local enabled_deps = {}
            function add_boost_deps(lib) 
                table.insert(enabled_deps, lib)
                for _, dep in ipairs(libnames[lib]) do
                    add_boost_deps(dep)
                end
            end

            for module, deps in pairs(modules) do
                if package:config(module) then
                    for _, dep in ipairs(deps) do
                        add_boost_deps(dep)
                    end
                end
            end
            enabled_deps = table.unique(enabled_deps)

            for _, dep in ipairs(enabled_deps) do
                package:config_set(dep, true)
            end
        end

        local version = package:version()
        if version:ge("1.84.0") then
            package:add("deps", "cmake")
            package:add("deps", "ninja")
        end
        function get_linkname(package, libname)
            local linkname
            if package:is_plat("windows") then
                linkname = (package:config("shared") and "boost_" or "libboost_") .. libname
            else
                linkname = "boost_" .. libname
            end
            if libname == "python" or libname == "numpy" then
                linkname = linkname .. package:config("pyver"):gsub("%p+", "")
            end
            if package:config("multi") then
                linkname = linkname .. "-mt"
            end
            if package:is_plat("windows") then
                local vs_runtime = package:config("vs_runtime")
                if package:config("shared") then
                    if package:debug() then
                        linkname = linkname .. "-gd"
                    end
                elseif vs_runtime == "MT" then
                    linkname = linkname .. "-s"
                elseif vs_runtime == "MTd" then
                    linkname = linkname .. "-sgd"
                elseif vs_runtime == "MDd" then
                    linkname = linkname .. "-gd"
                end
            else
                if package:debug() then
                    linkname = linkname .. "-d"
                end
            end
            return linkname
        end
        -- we need the fixed link order
        local sublibs = {log = {"log_setup", "log"},
                         python = {"python", "numpy"},
                         stacktrace = {"stacktrace_backtrace", "stacktrace_basic"}}
        for _, libname in ipairs(libnames) do
            local libs = sublibs[libname]
            if libs then
                for _, lib in ipairs(libs) do
                    package:add("links", get_linkname(package, lib))
                end
            else
                package:add("links", get_linkname(package, libname))
            end
        end

        local headeronly = true
        for _, libname in ipairs(libnames) do
            if package:config(libname) then
                headeronly = false
                break
            end
        end
        package:set("kind", "library", {headeronly = headeronly})

    end)

    on_install("macosx", "linux", "windows", "bsd", "mingw", "cross", "iphoneos", function (package)
        local version = package:version()
        if version:ge("1.84.0") then
            import("post184", {rootdir = os.scriptdir()})(modules, package)
        else
            import("pre184", {rootdir = os.scriptdir()})(libnames, package)
        end
    end)

    on_test(function (package)
        assert(package:check_cxxsnippets({test = [[
            #include <boost/core/addressof.hpp>

            struct useless_type { };

            class nonaddressable {
                useless_type operator&() const;
            };

            void f() {
                nonaddressable x;
                nonaddressable* xp = boost::addressof(x);
            }
        ]]}, {configs = {languages = "c++14"}}))

        if package:config("date_time") then
            assert(package:check_cxxsnippets({test = [[
                #include <boost/date_time/gregorian/gregorian.hpp>
                static void test() {
                    boost::gregorian::date d(2010, 1, 30);
                }
            ]]}, {configs = {languages = "c++14"}}))
        end
    end)
