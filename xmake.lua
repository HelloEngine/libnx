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
    if is_mode("debug") then
        set_basename("nxd")
    else
        set_basename("nx")
    end
    set_toolchains("aarch64-none-elf@devkit-a64")
    set_kind("static")
    add_packages("bin2s")
    add_defines("LIBNX_NO_DEPRECATION", "__SWITCH__")
    add_files("nx/source/**.s","nx/source/**.c")
    add_includedirs("nx/data/","nx/include/", "nx/include/switch/", "nx/external/bsd/include/")
    add_cflags("-g", 
        "-Wall", 
        "-Werror",
        "-ffunction-sections", 
        "-fdata-sections", 
        "-march=armv8-a+crc+crypto", 
        "-mtune=cortex-a57",
        "-mtp=soft",
        "-fPIC", 
        "-ftls-model=local-exec")
    add_cxxflags("-g", 
        "-Wall", 
        "-Werror",
        "-ffunction-sections", 
        "-fdata-sections", 
        "-march=armv8-a+crc+crypto", 
        "-mtune=cortex-a57",
        "-mtp=soft",
        "-fPIC", 
        "-ftls-model=local-exec",
        "-fno-rtti",
        "-fno-exceptions",
        "-std=gnu++11")
    add_asflags("-g",
        "-march=armv8-a+crc+crypto", 
        "-mtune=cortex-a57",
        "-mtp=soft",
        "-fPIC", 
        "-ftls-model=local-exec")

    on_load(function(target)
        assert(is_plat("cross"))
        assert(is_host("windows") or is_subhost("msys"))
    end)

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
    add_deps("switch-tools")

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

        io.writefile(packagedir .. "/rules/switch.lua", [[
rule("switch")
    on_config(function(target)
        -- target:add("packages", "switch-tools")
        
        --flags
        target:set("policy", "check.auto_ignore_flags", false)
        local specs = os.getenv("LIBNX") .. "/xswitch.specs"
        local arch = {
            "-march=armv8-a+crc+crypto", 
            "-mtune=cortex-a57", 
            "-mtp=soft", 
            "-fPIE"
        }
        local cflags = {
            "-g", 
            "-Wall", 
            "-O2",
            "-ffunction-sections",
            "-MMD", "-MP", "-MF",
            table.unpack(arch)
        }
        local cxxflags = {
            "-fno-rtti",
            "-fno-exceptions", 
            table.unpack(cflags)
        }
        local asflags = {
            "-g", 
            table.unpack(arch)
        }
        local ldflags = {
            "-specs=" .. specs, 
            "-g",
            string.format("-Wl,-Map,build/%s.map", target:name()),
            table.unpack(arch),
        }
        target:add("cxxflags", table.unpack(cxxflags))
        target:add("cflags", table.unpack(cflags))
        target:add("asflags", table.unpack(asflags))
        target:add("ldflags", table.unpack(ldflags))
        target:add("defines", "__SWITCH__")
    end)

    on_link(function(target)
        import("core.tool.linker")
        import("core.project.config")

        print("on_link:" .. linker.linkcmd("binary", {"cc", "cxx", "as"}, target:objectfiles(), target:name()..".elf", {target = target}))

        local buildir = config.get("buildir")
        local outfile = string.format("%s/%s.elf", buildir, target:name())
        linker.link("binary", {"cc", "cxx", "as"}, target:objectfiles(), outfile, {target = target})
    end)

    
    after_link(function(target)
        -- -- Import task module
        -- import("core.project.task")
        -- -- Run the nro task
        -- task.run("nro")

        -- author [可选]作者名，默认为HelloGame，存储在nacp中
        -- version [可选]版本号，默认为1.0.0，存储在nacp中
        -- titleid [可选]应用标识符，存储在nacp中
        -- apptitle [可选]应用名，默认为target名，存储在nacp中
        -- icon [可选]图标，不传会用默认图标
        -- romfsdir [可选]romfs目录

        import("core.project.project")
        import("core.project.config")

        --参数
        local author = target:values("author") or "HelloGame"
        local version = target:values("version") or "1.0.0"
        local apptitle = target:values("apptitle") or target:name()
        local titleid = target:values("titleid") or false
        local default_icon = os.getenv("LIBNX") .. "/default_icon.jpg"
        local icon = target:values("icon") or default_icon
        local romfsdir = target:values("romfsdir") or false

        --标准方式只需要add_requires("switch-tools"),不需要去add_packages("switch-tools")
        local bin = os.getenv("SWITCH_TOOLS") .. "/bin"
        if not os.exists(bin .. "/nacptool.exe") then
            cprint("check switch-tools package...")

            local switchtools = project.required_package("switch-tools")
            if not switchtools then
                raise("please add add_requires(\"switch-tools\") to xmake.lua!")
            end
    
            bin = switchtools:installdir() .. "/bin"   
        end
        os.addenv("PATH", bin) 

        --生成nacp
        local buildir = config.get("buildir")
        local nacpfile = string.format("%s/%s.nacp", buildir, target:name())
        local nacpcmd = {"--create", apptitle, author, version, nacpfile}
        if titleid then
            nacpcmd[#nacpcmd + 1] = "--titleid=" .. titleid
        end
        os.execv("nacptool", nacpcmd)
        --检查nacp
        if not os.exists(nacpfile) then
            raise("failed to create .nacp file")
        end

        --生成nro
        local elffile = string.format("%s/%s.elf", buildir, target:name())
        --检查elf文件
        if not os.exists(elffile) then
            raise("can not find .elf file")
        end
        local nrofile = string.format("%s/%s.nro", buildir, target:name())
        local nrocmd = {elffile, nrofile, "--icon=".. icon, "--nacp=" .. nacpfile}
        if romfsdir then
            nrocmd[#nrocmd + 1] = "--romfsdir=" .. romfsdir
        end
        os.execv("elf2nro", nrocmd)
        --检查nrofile
        if not os.exists(nrofile) then
            raise("failed to create .nro file")
        end

        cprint("build .nro success")
    end)
rule_end()
        ]])
    end)
