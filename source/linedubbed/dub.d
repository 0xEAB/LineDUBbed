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

TestResult build(PackageHandle packageHandle, CompilerInfo compiler)
{
    alias ICompiler = dub.compilers.compiler.Compiler;

    BuildPlatform platform = determineBuildPlatform();
    BuildSettings settings = packageHandle._package.getBuildSettings(platform, null);

    settings.targetType = TargetType.staticLibrary;
    ICompiler c = getCompiler(compiler.path);

    string buildLog;
    int status;
    bool callbackExecuted;

    try // Compiler.invoke throws on error
    {
        c.invoke(settings, platform, (int code, string output) {
            status = code;
            buildLog = output;
            callbackExecuted = true;
        });
    }
    catch (Exception ex)
    {
        if (!(callbackExecuted && (status != 0)))
        {
            // something went terribly wrong
            throw ex;
        }
        // build failed, so what?
    }

    immutable tst = (status == 0) ? TestStatus.success : TestStatus.failure;
    return TestResult(packageHandle._dubPackage, tst, compiler, buildLog);
}
