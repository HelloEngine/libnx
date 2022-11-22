add_rules("mode.debug", "mode.release")
set_allowedplats("cross")

add_repositories("xswitch-repo https://github.com/HelloEngine/xswitch-repo.git main")
add_requires("devkit-a64", "bin2s")
target("libnx")
    if is_mode("debug") then
        set_basename("nxd")
    else
        set_basename("nx")
    end
    set_kind("static")
    add_packages("devkit-a64", "bin2s")
    add_rules("@devkit-a64/aarch64")
    set_toolchains("cross@devkit-a64")
    add_defines("LIBNX_NO_DEPRECATION", "__SWITCH__")
    add_files("nx/source/**.s","nx/source/**.c")
    add_includedirs("nx/data/","nx/include/", "nx/include/switch/", "nx/external/bsd/include/")

    on_config(function(target)
        local binfile = os.curdir() .. "/nx/data/default_font.bin"
        local outdata, errdata
        if is_subhost("msys") then
            outdata, errdata = os.iorun("bin2s " .. binfile)
            print(errdata )
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
        os.cp(target:scriptdir() .. "/nx/xswitch.specs", target:installdir())
        os.cp(target:scriptdir() .. "/nx/xswitch.ld", target:installdir())
    end)

    on_package(function(target)
        local packagedir = "$(buildir)/packages/" .. target:name() .. "/"
        os.cp(target:targetdir(), packagedir .. "/lib/")
        os.cp(target:scriptdir() .. "/nx/include", packagedir)
        os.cp(target:scriptdir() .. "/nx/external/bsd/include", packagedir)
        os.cp(target:scriptdir() .. "/nx/default_icon.jpg", packagedir)
        os.cp(target:scriptdir() .. "/nx/xswitch.specs", packagedir)
        os.cp(target:scriptdir() .. "/nx/xswitch.ld", packagedir)

        io.writefile(packagedir .. "/xmake.lua", [[
package("libnx")
    add_deps("devkit-a64","switch-tools")

    on_load(function(package)
        package:set("installdir", os.scriptdir())
        package:addenv("LIBNX", package:installdir())
    end)
    
    on_fetch("cross@windows", "cross@msys", function (package)
        local result = {}
        if is_mode("debug") then
            result.linkdirs = package:installdir("lib/debug")
            result.links = "nxd"
        else
            result.linkdirs = package:installdir("lib/release")
            result.links = "nx"
        end
        result.includedirs = package:installdir("include")
        return result
    end)
package_end()
        ]])
    end)
