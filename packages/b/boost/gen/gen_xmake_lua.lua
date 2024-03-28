-- xmake l gen_xmake_lua.lua
print("Cloning boost")
os.iorunv("git clone https://github.com/boostorg/boost.git -b boost-1.84.0 --depth 1 --recursive")

print("Parsing modules")
local modules = "local libnames = {"
for _, module in ipairs(os.filedirs("boost/libs/*")) do
    -- extract dependencies
    local cmakelist_path = path.join(module, "CMakeLists.txt")
    if os.isfile(cmakelist_path) then
        local cmakelist = io.readfile(cmakelist_path)
        local target_links = cmakelist:match("target_link_libraries%(([^%)]*)%)")
        local deps = {}
        modules = modules .. '["' .. path.filename(module) .. '"]'
        if target_links then
            modules = modules .. " = {\n"
            for dep in target_links:gmatch("Boost::([^\n]*)\n") do
                modules = modules .. '    "' .. dep .. '",\n'
            end
            modules = modules .. "}"
        else
            modules = modules .. " = {}"
        end
        modules = modules .. ",\n"
    end
end
modules = modules .. "}"

io.writefile("modules.lua", modules)

print("Cleaning")
os.rm("boost")
