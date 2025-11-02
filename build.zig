const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zlib_dep = b.dependency("zlib", .{
        .target = target,
        .optimize = optimize,
    });

    const elfutils_dep = b.dependency("elfutils", .{
        .target = target,
        .optimize = optimize,
    });

    const libtools = b.addLibrary(.{
        .name = "tools",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    libtools.addCSourceFiles(.{
        .root = b.path("tools/lib"),
        .files = &tools_lib_src,
    });
    libtools.addIncludePath(b.path("tools/include"));

    const libbpf = b.addLibrary(.{
        .name = "bpf",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    libbpf.addCSourceFiles(.{
        .root = b.path("tools/lib/bpf"),
        .files = &bpf_lib_src,
    });
    libbpf.linkLibrary(elfutils_dep.artifact("elf"));
    libbpf.root_module.addCMacro("_LARGEFILE64_SOURCE", "");
    libbpf.root_module.addCMacro("_FILE_OFFSET_BITS", "64");
    libbpf.addIncludePath(b.path("tools/include"));
    libbpf.addIncludePath(b.path("tools/include/uapi"));
    libbpf.addIncludePath(zlib_dep.artifact("z").getEmittedIncludeTree());

    const libsubcmd = b.addLibrary(.{
        .name = "subcmd",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    libsubcmd.addCSourceFiles(.{
        .root = b.path("tools/lib/subcmd"),
        .files = &subcmd_lib_src,
    });
    libsubcmd.addIncludePath(b.path("tools/include"));
    libsubcmd.root_module.addCMacro("_LARGEFILE64_SOURCE", "");
    libsubcmd.root_module.addCMacro("_FILE_OFFSET_BITS", "64");
    libsubcmd.root_module.addCMacro("_GNU_SOURCE", "");

    const elfutils_upstream = elfutils_dep.builder.dependency("elfutils", .{});

    inline for (scripts) |script| {
        const exe = b.addExecutable(.{
            .name = script.name,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });
        exe.addCSourceFiles(.{
            .root = b.path(script.root),
            .files = script.sources,
            .flags = &.{},
        });
        if (std.mem.startsWith(u8, script.root, "tools")) {
            exe.linkLibrary(libbpf);
            exe.linkLibrary(libsubcmd);
            exe.linkLibrary(libtools);
            exe.addIncludePath(elfutils_upstream.path("libelf"));
            exe.addIncludePath(b.path("tools/include"));
            exe.addIncludePath(b.path("tools/lib"));
            exe.addIncludePath(b.path("tools/include/uapi"));
        } else {
            exe.root_module.addCMacro("NO_YAML", "1");
            exe.addIncludePath(b.path("include"));
            exe.addIncludePath(b.path("tools/include"));
            exe.addIncludePath(b.path("scripts/include"));
            exe.addIncludePath(b.path("scripts/dtc/libfdt"));
        }
        b.getInstallStep().dependOn(&b.addInstallArtifact(exe, .{
            .dest_dir = .{ .override = script.install_dir },
        }).step);
    }
}

const tools_lib_src = [_][]const u8{
    "rbtree.c",
    "zalloc.c",
    "string.c",
    "ctype.c",
    "str_error_r.c",
};

const bpf_lib_src = [_][]const u8{
    "libbpf.c",
    "bpf.c",
    "nlattr.c",
    "btf.c",
    "libbpf_errno.c",
    "str_error.c",
    "netlink.c",
    "bpf_prog_linfo.c",
    "libbpf_probes.c",
    "hashmap.c",
    "btf_dump.c",
    "ringbuf.c",
    "strset.c",
    "linker.c",
    "gen_loader.c",
    "relo_core.c",
    "usdt.c",
    "zip.c",
    "elf.c",
    "features.c",
    "btf_iter.c",
    "btf_relocate.c",
};

const subcmd_lib_src = [_][]const u8{
    "exec-cmd.c",
    "help.c",
    "pager.c",
    "parse-options.c",
    "run-command.c",
    "sigchain.c",
    "subcmd-config.c",
};

const Scripts = struct {
    name: []const u8,
    root: []const u8,
    sources: []const []const u8,
    install_dir: std.Build.InstallDir = .{ .custom = "scripts" },
};

const scripts: []const Scripts = &.{
    .{
        .name = "fixdep",
        .root = "scripts/basic",
        .sources = &.{
            "fixdep.c",
        },
        .install_dir = .{ .custom = "scripts/basic" },
    },
    .{
        .name = "modpost",
        .root = "scripts/mod",
        .sources = &.{
            "modpost.c",
            "file2alias.c",
            "sumversion.c",
            "symsearch.c",
        },
        .install_dir = .{ .custom = "scripts/mod" },
    },
    .{
        .name = "fdtoverlay",
        .root = "scripts/dtc",
        .sources = &.{
            "libfdt/fdt.c",
            "libfdt/fdt_ro.c",
            "libfdt/fdt_wip.c",
            "libfdt/fdt_sw.c",
            "libfdt/fdt_rw.c",
            "libfdt/fdt_strerror.c",
            "libfdt/fdt_empty_tree.c",
            "libfdt/fdt_addresses.c",
            "libfdt/fdt_overlay.c",
            "fdtoverlay.c",
            "util.c",
        },
        .install_dir = .{ .custom = "scripts/dtc" },
    },
    .{
        .name = "dtc",
        .root = "scripts/dtc",
        .sources = &.{
            "dtc.c",
            "flattree.c",
            "fstree.c",
            "data.c",
            "livetree.c",
            "treesource.c",
            "srcpos.c",
            "checks.c",
            "util.c",
            "dtc-lexer.lex.c",
            "dtc-parser.tab.c",
        },
        .install_dir = .{ .custom = "scripts/dtc" },
    },
    .{
        .name = "conf",
        .root = "scripts/kconfig",
        .sources = &.{
            "conf.c",
            "confdata.c",
            "expr.c",
            "lexer.lex.c",
            "menu.c",
            "parser.tab.c",
            "preprocess.c",
            "symbol.c",
            "util.c",
        },
        .install_dir = .{ .custom = "scripts/kconfig" },
    },
    .{
        .name = "modpost",
        .root = "scripts/mod",
        .sources = &.{
            "mk_elfconfig.c",
        },
        .install_dir = .{ .custom = "scripts/mod" },
    },
    .{
        .name = "sorttable",
        .root = "scripts",
        .sources = &.{
            "sorttable.c",
        },
    },
    .{
        .name = "kallsyms",
        .root = "scripts",
        .sources = &.{
            "kallsyms.c",
        },
    },
    .{
        .name = "kallsyms",
        .root = "scripts",
        .sources = &.{
            "kallsyms.c",
        },
    },
    .{
        .name = "asn1_compiler",
        .root = "scripts",
        .sources = &.{
            "asn1_compiler.c",
        },
    },
    .{
        .name = "resolve_btfids",
        .root = "tools/bpf/resolve_btfids",
        .sources = &.{"main.c"},
        .install_dir = .{ .custom = "tools/bpf/resolve_btfids" },
    },
};
