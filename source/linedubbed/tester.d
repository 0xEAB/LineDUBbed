/+
                      Copyright 0xEAB 2018
     Distributed under the Boost Software License, Version 1.0.
        (See accompanying file LICENSE_1_0.txt or copy at
              https://www.boost.org/LICENSE_1_0.txt)
 +/
module linedubbed.tester;

import std.conv : to;
import std.exception : enforce;
import std.process : Config, execute;
import linedubbed.registry;

struct DUBConfig
{
    string path;
    string cache;
    string registryURL;
}

struct Compiler
{
    string path;
    string id;
}

struct TestResult
{
    DUBPackage dubPackage;
    TestStatus status;
    Compiler compiler;
    string buildLog;
    string testDirectory;
}

enum TestStatus
{
    unknown = 0b_0000,
    fetched = 0b_0001,
    failure = 0b_0011,
    success = 0b_0111,
}

Compiler getCompilerHandle(string compilerPath) @safe
{
    return Compiler(compilerPath, getCompilerVersionString(compilerPath));
}

string getCompilerVersionString(string compilerPath) @safe
{
    import std.process : execute;
    import std.string : indexOf, stripRight;

    auto cmd = execute([compilerPath, "--version"]);
    enforce(cmd.status == 0, "Bad compiler path");

    string txt = cmd.output;
    // first line of LDC version string ends with ':'
    immutable lineEnd = txt.indexOf("\n");
    txt = txt[0 .. ((lineEnd < 0) ? $ : lineEnd)].stripRight(":");

    return txt;
}

TestResult create(DUBConfig dub, DUBPackage package_, string testDirectory)
{
    import std.file : exists, mkdir, rmdirRecurse;
    import std.path : buildPath;
    import std.stdio : File;

    if (testDirectory.exists)
    {
        testDirectory.rmdirRecurse();
    }

    testDirectory.mkdir();

    File dubJson = File(testDirectory.buildPath("dub.json"), "w");
    dubJson.writef(import("dummy.json"), package_.name, package_.version_);
    dubJson.flush();

    File dummyD = File(testDirectory.buildPath("dummy.d"), "w");
    dummyD.write(import("dummy.d"));
    dummyD.flush();

    return TestResult(package_, TestStatus.fetched, Compiler(), null, testDirectory);
}

TestResult build(DUBConfig dub, TestResult createdTest, Compiler compiler, bool force = false) @safe
{
    alias tr = createdTest;
    alias package_ = createdTest.dubPackage;

    // dfmt off
    auto args = [
        dub.path,
        "build",
        "--cache=" ~ dub.cache, // DUB issue#1556
        "--registry=" ~ dub.registryURL,
        "--build=plain",
        "--compiler=" ~ compiler.path,
    ];
    // dfmt on

    if (force)
    {
        args ~= "--force";
    }

    auto cmd = execute(args, null, Config.none, ulong.max, tr.testDirectory);
    immutable status = (cmd.status == 0) ? TestStatus.success : TestStatus.failure;
    tr.status = status;
    tr.compiler = compiler;
    tr.buildLog = cmd.output;
    return tr;
}
