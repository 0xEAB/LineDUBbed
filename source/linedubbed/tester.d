/+
                      Copyright 0xEAB 2018
     Distributed under the Boost Software License, Version 1.0.
        (See accompanying file LICENSE_1_0.txt or copy at
              https://www.boost.org/LICENSE_1_0.txt)
 +/
module linedubbed.tester;

import std.conv : to;
import std.exception : enforce;
import std.process : execute;
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

TestResult fetch(DUBConfig dub, DUBPackage package_) @safe
{
    // dfmt off
    auto args = [
        dub.path,
        "--cache=" ~ dub.cache,
        "--registry=" ~ dub.registryURL,
        "fetch", package_.name,
        "--version=" ~ package_.version_
    ];
    // dfmt on

    auto cmd = execute(args);

    enforce(cmd.status == 0, "Failed to fetch: " ~ package_.to!string ~ "\n" ~ cmd.output);
    return TestResult(package_, TestStatus.fetched, Compiler(), null);
}

TestResult build(DUBConfig dub, DUBPackage package_, Compiler compiler, bool force = false) @safe
{
    // dfmt off
    auto args = [
        dub.path,
        "build", package_.name,
        "--cache=" ~ dub.cache, // DUB issue#1556
        "--registry=" ~ dub.registryURL,
        "--build=plain",
        "--compiler=" ~ compiler.path,
        //"--version=" ~ package_.version_, // DUB issue#1557
    ];
    // dfmt on

    if (force)
    {
        args ~= "--force";
    }

    auto cmd = execute(args);
    immutable status = (cmd.status == 0) ? TestStatus.success : TestStatus.failure;
    return TestResult(package_, status, compiler, cmd.output);
}
