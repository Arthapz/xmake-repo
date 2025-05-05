package("gettext")

    set_homepage("https://www.gnu.org/software/gettext/")
    set_description("GNU internationalization (i18n) and localization (l10n) library.")

    set_urls("https://ftpmirror.gnu.org/gettext/gettext-$(version).tar.xz",
             "https://ftp.gnu.org/gnu/gettext/gettext-$(version).tar.xz",
             {version = function (version) return version:gsub('%-', '.') end})
    add_versions("0.19.8-1", "105556dbc5c3fbbc2aa0edb46d22d055748b6f5c7cd7a8d99f8e7eb84e938be4")
    add_versions("0.21", "d20fcbb537e02dcf1383197ba05bd0734ef7bf5db06bdb241eb69b7d16b73192")
    add_versions("0.21.1", "50dbc8f39797950aa2c98e939947c527e5ac9ebd2c1b99dd7b06ba33a6767ae6")
    add_versions("0.22.5", "fe10c37353213d78a5b83d48af231e005c4da84db5ce88037d88355938259640")
    add_versions("0.23.1", "c1f97a72a7385b7e71dd07b5fea6cdaf12c9b88b564976b23bd8c11857af2970")
    add_versions("0.24.1", "6164ec7aa61653ac9cdfb41d5c2344563b21f707da1562712e48715f1d2052a6")

    if is_plat("macosx") then
        add_frameworks("CoreFoundation")
    end
    add_deps("libiconv")

    on_load("macosx", "linux", function(package)
        package:add("deps", "autotools")
    end)

    on_load(function(package)
        if is_subhost("windows") then
            -- get msys2 sh to avoid using git sh
            local msystem = "MINGW" .. (package:is_arch64() and "64" or "32")
            package:add("deps", "msys2", {configs = {msystem = msystem, base_devel = true, gcc =  true, make = true}})
        end
    end)

    on_install("macosx", "linux", "android", function (package)
        local configs = {"--disable-dependency-tracking",
                         "--disable-silent-rules",
                         "--with-included-libcroco",
                         "--with-included-glib",
                         "--with-included-libunistring",
                         "--with-lispdir=#{elisp}",
                         "--disable-java",
                         "--disable-csharp",
                         "--without-emacs",
                         "--without-git",
                         "--without-bzip2",
                         "--without-cvs",
                         "--without-xz"}
        if package:config("shared") then
            table.insert(configs, "--disable-static")
        else
            table.insert(configs, "--disable-shared")
        end
        if package:debug() then
            table.insert(configs, "--enable-debug")
        end
        if package:config("pic") ~= false then
            table.insert(configs, "--with-pic")
        end
        if package:is_plat("macosx") then
            table.insert(configs, "--with-included-gettext")
        end
        if package:is_plat("android") then
            if package:version():le("0.20") then
                io.replace("./gettext-tools/configure", "#define gid_t int", "")
                io.replace("./gettext-tools/configure", "#define uid_t int", "")
                io.replace("./gettext-runtime/configure", "#define gid_t int", "")
                io.replace("./gettext-runtime/configure", "#define uid_t int", "")
                io.replace("./gettext-tools/gnulib-lib/spawn.in.h", "@HAVE_SPAWN_H@", "0")
                io.replace("./gettext-tools/gnulib-lib/spawn.in.h", "@HAVE_POSIX_SPAWNATTR_T@", "0")
                io.replace("./gettext-tools/gnulib-lib/spawn.in.h", "@HAVE_POSIX_SPAWN_FILE_ACTIONS_T@", "0")
                io.replace("./gettext-runtime/src/Makefile.in",
                    "bin_PROGRAMS = gettext$(EXEEXT) ngettext$(EXEEXT) envsubst$(EXEEXT)",
                    "bin_PROGRAMS =", {plain = true})
                io.replace("./gettext-tools/src/Makefile.in",
                    "bin_PROGRAMS = .*noinst_PROGRAMS =",
                    "bin_PROGRAMS =\nnoinst_PROGRAMS =")
                io.replace("./gettext-tools/src/Makefile.in",
                    "noinst_PROGRAMS = hostname$(EXEEXT) urlget$(EXEEXT) \\",
                    "bin_PROGRAMS =", {plain = true})
                io.replace("./gettext-tools/src/Makefile.in",
                    "cldr-plurals$(EXEEXT)",
                    "", {plain = true})
                io.replace("./gettext-tools/src/Makefile.in",
                    "install-exec-local:",
                    "install-exec-local: \n\ninstall-exec-local_: ", {plain = true})
                io.replace("./gettext-tools/config.h.in", "#undef ICONV_CONST", "#define ICONV_CONST const")
                io.replace("./gettext-runtime/config.h.in", "#undef ICONV_CONST", "#define ICONV_CONST const")
                io.replace("./gettext-tools/libgrep/langinfo.in.h", "@HAVE_LANGINFO_H@", "0")
                io.replace("./gettext-tools/gnulib-lib/langinfo.in.h", "@HAVE_LANGINFO_H@", "0")
                io.replace("./gettext-runtime/gnulib-lib/langinfo.in.h", "@HAVE_LANGINFO_H@", "0")
            end
            if is_subhost("windows") then
                -- needed to avoid link errors to rpl_fputc, rpl_write, ...
                -- rpl_* variants are enabled because SIGPIPE check fail, but i don't understand why, as i'm not very knowledgeable on msys2 and android, the fix is for now is this hack
                for _, conffile in ipairs({"./configure", "./gettext-tools/configure", "./gettext-runtime/configure"}) do
                    io.replace(conffile, "REPLACE_STDIO_WRITE_FUNCS=1", "REPLACE_STDIO_WRITE_FUNCS=0")
                    io.replace(conffile, "REPLACE_WRITE=1", "REPLACE_WRITE=0")
                end
            end
        end
        local cflags = {}
        local ldflags = {}
        for _, dep in ipairs(package:orderdeps()) do
            local fetchinfo = dep:fetch()
            if fetchinfo then
                for _, includedir in ipairs(fetchinfo.includedirs or fetchinfo.sysincludedirs) do
                    table.insert(cflags, "-I" .. includedir)
                end
                for _, linkdir in ipairs(fetchinfo.linkdirs) do
                    table.insert(ldflags, "-L" .. linkdir)
                end
                for _, link in ipairs(fetchinfo.links) do
                    table.insert(ldflags, "-l" .. link)
                end
            end
        end
        import("package.tools.autoconf")
        local envs_opt = {cflags = clags, ldflags = ldflags}
        local envs = os.joinenvs(autoconf.buildenvs(package, envs_opt), os.getenvs())
        envs.SHELL = "sh"
        if package:is_plat("android") and is_subhost("windows") then
            table.insert(configs, "--prefix=" .. package:installdir():gsub("\\", "/"))
            local triples =
            {
                ["armv5te"]     = "arm-linux-androideabi",  -- deprecated
                ["armv7-a"]     = "arm-linux-androideabi",  -- deprecated
                ["armeabi"]     = "arm-linux-androideabi",  -- removed in ndk r17
                ["armeabi-v7a"] = "arm-linux-androideabi",
                ["arm64-v8a"]   = "aarch64-linux-android",
                i386            = "i686-linux-android",     -- deprecated
                x86             = "i686-linux-android",
                x86_64          = "x86_64-linux-android",
                mips            = "mips-linux-android",     -- removed in ndk r17
                mips64          = "mips64-linux-android"    -- removed in ndk r17
            }
            table.insert(configs, "--host=" .. (triples[package:arch()] or triples["armeabi-v7a"]))
            os.vrunv("./configure", configs, {shell = true, envs = os.joinenvs(envs, autoconf.autogen_envs(package, envs_opt))})

            local njob = import("core.base.option").get("jobs") or tostring(os.default_njob())
            local argv = {"-j" .. njob}
            if option.get("verbose") then
                table.insert(argv, "V=1")
            end
            os.vrunv("make", argv, {envs = envs})
            os.vrunv("make", {"install"}, {envs = envs})
        else
            autoconf.install(package, configs, {envs = envs})
        end
        package:addenv("PATH", "bin")
    end)

    on_test(function (package)
        assert(package:has_cfuncs("ngettext", {includes = "libintl.h"}))
    end)
