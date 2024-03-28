function main(modules, package)
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
        end
    end

    table.insert(configs, "-DBOOST_INCLUDE_LIBRARIES=" .. table.concat(enabled_libraries, ";"))

    import("package.tools.cmake").install(package, configs, {cmake_generator = "Ninja"})
end

