/+
                      Copyright 0xEAB 2018
     Distributed under the Boost Software License, Version 1.0.
        (See accompanying file LICENSE_1_0.txt or copy at
              https://www.boost.org/LICENSE_1_0.txt)
 +/
module linedubbed.dub;

import std.conv : to;
import dub.compilers.compiler;
import dub.dependency;
import dub.dub;
import dub.generators.generator;
import dub.internal.vibecompat.core.log : LogLevel, setLogLevel;
import dub.internal.vibecompat.inet.url : URL;
import dub.packagemanager;
import dub.packagesuppliers;
import dub.platform;
import dub.package_;
import dub.project;
import dub.recipe.packagerecipe;
import linedubbed.registry : DUBPackage;
import linedubbed.tester;

alias CompilerInfo = linedubbed.tester.Compiler;

static this()
{
    setLogLevel(LogLevel.none);
}

struct DUBHandle
{
private:
    Dub _dub;
}

struct PackageHandle
{
    @property bool error() const
    {
        return (this._package is null);
    }

private:
    DUBPackage _dubPackage;
    Package _package;
}

DUBHandle getDUB(string registryURL, string cache)
{
    Dub dub = new Dub(".", [new RegistryPackageSupplier(URL(registryURL))],
            SkipPackageSuppliers.all);
    dub.defaultPlacementLocation = cache.to!PlacementLocation;
    return DUBHandle(dub);
}

PackageHandle fetch(DUBHandle dubHandle, DUBPackage package_)
{
    immutable d = Dependency(package_.version_);
    FetchOptions fo;
    fo |= FetchOptions.forceBranchUpgrade;
    Package p = dubHandle._dub.fetch(package_.name, d,
            dubHandle._dub.defaultPlacementLocation, fo);
    return PackageHandle(package_, p);
}

TestResult build(DUBHandle dubHandle, PackageHandle packageHandle, CompilerInfo compiler)
{
    dubHandle._dub.loadPackage(packageHandle._package);

    WontLinkCompiler c = new WontLinkCompiler(getCompiler(compiler.path));
    BuildSettings tmp;
    BuildPlatform platform = c.determinePlatform(tmp, compiler.path);
    string config = dubHandle._dub.project.getDefaultConfiguration(platform);
    BuildSettings bsettings = packageHandle._package.getBuildSettings(platform, config);
    bsettings.addDFlags(tmp.dflags);
    bsettings.targetType = TargetType.staticLibrary;
    c.prepareBuildSettings(bsettings);
    c.extractBuildOptions(bsettings);
    c.setTarget(bsettings, platform);

    GeneratorSettings gsettings;
    gsettings.platform = platform;
    gsettings.config = config;
    gsettings.buildType = "plain";
    gsettings.buildMode = BuildMode.separate;
    gsettings.compiler = c;
    gsettings.buildSettings = bsettings;
    gsettings.combined = true;
    //gsettings.run = false;
    //gsettings.runArgs = [];
    gsettings.force = true;
    //gsettings.rdmd = false;
    //gsettings.tempBuild = false;
    //gsettings.parallelBuild = false;

    try
    {
        dubHandle._dub.generateProject("build", gsettings);
    }
    catch (Exception)
    {
    }

    immutable tst = (c._status == 0) ? TestStatus.success : TestStatus.failure;
    return TestResult(packageHandle._dubPackage, tst, compiler, c._buildLog);
}

private:
alias ICompiler = dub.compilers.compiler.Compiler;

/+
    Decorator for fooling DUB
 +/
class WontLinkCompiler : ICompiler
{
    private
    {
        ICompiler _compiler;
        string _buildLog;
        int _status;
    }

    public
    {
        @property string name() const
        {
            return this._compiler.name;
        }
    }

    public this(ICompiler compiler)
    {
        this._compiler = compiler;
    }

    public
    {
        BuildPlatform determinePlatform(ref BuildSettings settings,
                string compiler_binary, string arch_override = null)
        {
            return this._compiler.determinePlatform(settings, compiler_binary, arch_override);
        }

        void prepareBuildSettings(ref BuildSettings settings,
                BuildSetting supported_fields = BuildSetting.all) const
        {
            this._compiler.prepareBuildSettings(settings, supported_fields);
        }

        void extractBuildOptions(ref BuildSettings settings) const
        {
            this._compiler.extractBuildOptions(settings);
        }

        string getTargetFileName(in BuildSettings settings, in BuildPlatform platform) const
        {
            return this._compiler.getTargetFileName(settings, platform);
        }

        void setTarget(ref BuildSettings settings, in BuildPlatform platform,
                string targetPath = null) const
        {
            this._compiler.setTarget(settings, platform, targetPath);
        }

        void invoke(in BuildSettings settings, in BuildPlatform platform,
                void delegate(int, string) output_callback)
        {
            this._compiler.invoke(settings, platform, (int statusCode, string log) {
                if (output_callback)
                {
                    output_callback(statusCode, log);
                }

                this._status = statusCode;
                this._buildLog = log;
            });
        }

        void invokeLinker(in BuildSettings, in BuildPlatform, string[], void delegate(int, string))
        {
            // do nothing
            return;
        }

        string[] lflagsToDFlags(in string[] lflags) const
        {
            return this._compiler.lflagsToDFlags(lflags);
        }
    }
}
