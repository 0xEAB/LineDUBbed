/+
                      Copyright 0xEAB 2018
     Distributed under the Boost Software License, Version 1.0.
        (See accompanying file LICENSE_1_0.txt or copy at
              https://www.boost.org/LICENSE_1_0.txt)
 +/
module linedubbed.daemon;

import std.algorithm : filter, map;
import std.range : array, isInputRange, ElementType;
import std.string : leftJustify;
import std.stdio : File;

import linedubbed.database;
import linedubbed.registry;
import linedubbed.tester;

public
{
    import linedubbed.tester : DUBConfig;
}

void run(string registry, string dCompilerPath, DUBConfig dub, string testsDir, string sqliteDBPath, File log)
{
    Compiler compiler = getCompilerHandle(dCompilerPath);
    log.writeln(`Selected compiler: "`, compiler.id, `"`);
    log.writeln("Opening DB");
    Database db = openAndInitIfNotExists(sqliteDBPath);

    log.writeln("Fetching package list from ", registry);
    auto packages = registry.getPackages();
    log.writefln("Got a list of %u packages.", packages.length);

    log.writeln("Updating DB");
    auto dbPackages = db.getDatabasePackageHandle(packages);

    auto semver = dbPackages.filterNonSemVer.array;
    log.writefln("Will skip %u packages due non-semantic versioning.",
            (packages.length - semver.length));

    auto untested = db.determineUntestedPackages(semver).array;
    log.writefln("Found %u previously untested packages.", untested.length);
    immutable untestedC = untested.length - 1;
    foreach (idx, p; untested)
    {
        log.writef("%04u/%u  |  %s  |  init", idx, untestedC, p.name.leftJustify(20)[0 .. 20]);
        log.flush();
        TestResult tr = dub.create(p, testsDir);
        log.write(" . build");
        log.flush();
        tr = dub.build(tr, compiler, false);
        log.writeln(" . ", tr.status);
        db.saveTestResult(tr);
    }
}

bool isLatestTestedVersion(Database db, DUBPackage p)
{
    return (p.version_ == db.getLatestTestedVersion(p));
}

bool isUntested(Database db, DUBPackage p)
{
    return (db.getLatestTestedVersion(p) is null);
}

auto determineUntestedPackages(Range)(Database db, Range packages) @safe
        if (isInputRange!Range && is(ElementType!Range == DUBPackage))
{
    return packages.filter!(p => db.isUntested(p));
}

auto filterNonSemVer(Range)(Range packages) @safe
        if (isInputRange!Range && is(ElementType!Range == DUBPackage))
{
    // TODO: a proper filter
    return packages.filter!(p => (p.version_[0] != '~'));
}
