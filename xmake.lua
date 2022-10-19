add_rules("mode.debug", "mode.release")
set_plat("cross")
--set_version("master")
toolchain("aarch64-none-elf")
    set_kind("cross")
    on_load(function (toolchain)
        toolchain:load_cross_toolchain()
    end)
toolchain_end()

add_repositories("xswitch-repo https://github.com/HelloEngine/xswitch-repo.git main")
add_requires("devkit-a64", "bin2s")
target("libnx")
    set_basename("nx")
    set_toolchains("aarch64-none-elf@devkit-a64")
    add_rules("@devkita-a64/base")
    set_kind("static")
    add_packages("bin2s")
    add_defines("LIBNX_NO_DEPRECATION", "__SWITCH__")
    add_files("nx/source/**.s","nx/source/**.c")
    add_includedirs("nx/data/","nx/include/", "nx/include/switch/", "nx/external/bsd/include/")
    on_config(function(target)
        local binfile = os.curdir() .. "/nx/data/default_font.bin"
        assert(os.exists(binfile))
        local outdata, errdata
        if is_subhost("msys") then
            outdata, errdata = os.iorun("bin2s " .. binfile)
        else
            outdata, errdata = os.iorun("bin2s.exe " .. binfile)
        end
        io.writefile("nx/data/default_font_bin.s", outdata)
        io.writefile("nx/data/default_font_bin.h", [=[
            #pragma once
            extern const unsigned char default_font_bin[];
            extern const unsigned char default_font_bin_end[];
            extern const unsigned int default_font_bin_size;
        ]=])
        target:add("files", "nx/data/**.s")
    end)
    on_install(function(target)
        os.cp(target:targetfile(), target:installdir() .. "/lib/")
        os.cp(target:scriptdir() .. "/nx/include", target:installdir())
        os.cp(target:scriptdir() .. "/nx/external/bsd/include", target:installdir())
        os.cp(target:scriptdir() .. "/nx/default_icon.jpg", target:installdir())
        os.cp(target:scriptdir() .. "/nx/switch.specs", target:installdir())
        os.cp(target:scriptdir() .. "/nx/switch.ld", target:installdir())
    end)
    if is_mode("debug") then
        set_suffixname("d")
    end
