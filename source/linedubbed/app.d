/+
                      Copyright 0xEAB 2018
     Distributed under the Boost Software License, Version 1.0.
        (See accompanying file LICENSE_1_0.txt or copy at
              https://www.boost.org/LICENSE_1_0.txt)
 +/
module linedubbed.app;

import std.conv : to;
import std.file : exists, mkdirRecurse;
import std.getopt : config, defaultGetoptFormatter, getopt, GetoptResult;
import std.path : buildPath, dirName;
import std.stdio : File, stderr, stdout;

import linedubbed.daemon;

private:
enum appName = "LineDUBbed";

void main(string[] args)
{
    bool optPrintVersionInfo;
    string optCompilerPath;
    string optDUBCachePath;
    string optDUBPath;
    string optDUBListRegistryBaseURL;
    string optDUBRegistryBaseURL;
    string optSqliteDBPath;

    // dfmt off
	GetoptResult opt = getopt(
		args,
        config.passThrough,
        "cache", "DUB cache [local|system|user]", &optDUBCachePath,
        "compiler", "D compiler path", &optCompilerPath,
        "db", "SQLite database path", &optSqliteDBPath,
        "dub", "DUB executable path", &optDUBPath,
        "registry", "DUB registry baseURL", &optDUBRegistryBaseURL,
        "lregistry", "baseURL of DUB registry to fetch package list from", &optDUBListRegistryBaseURL,
        "version", "Display the version of this program.", &optPrintVersionInfo
	);
	// dfmt on

    if (opt.helpWanted || (args.length > 1))
    {
        stdout.printHelp(args[0], opt);
        return;
    }
    else if (optPrintVersionInfo)
    {
        stdout.printVersionInfo();
        return;
    }

    if (optCompilerPath is null)
    {
        optCompilerPath = "dmd";
    }

    if (optDUBPath is null)
    {
        optDUBPath = "dub";
    }

    if (optDUBCachePath is null)
    {
        optDUBCachePath = "local";
    }

    if (optSqliteDBPath is null)
    {
        optSqliteDBPath = thisExeDir.buildPath("lnd.sqlite3");
    }

    if (optDUBRegistryBaseURL is null)
    {
        optDUBRegistryBaseURL = "https://dub-registry.herokuapp.com";
    }

    if (optDUBListRegistryBaseURL is null)
    {
        optDUBListRegistryBaseURL = optDUBRegistryBaseURL;
    }

    run(optDUBListRegistryBaseURL, optCompilerPath, DUBConfig(optDUBPath,
            optDUBCachePath, optDUBRegistryBaseURL), optSqliteDBPath, stdout);
}

/++
    Returns: folder where the program's executable is located in
 +/
string thisExeDir() @safe
{
    import std.file : thisExePath;

    return thisExePath.dirName;
}

void printHelp(File target, string args0, GetoptResult opt)
{
    target.lockingTextWriter.defaultGetoptFormatter(appName ~ "\n\n  Usage:\n    "
            ~ args0 ~ " [options]\n\n\nAvailable options:\n==================", opt.options);
}

void printVersionInfo(File target)
{
    target.write(import("version.txt"));
}
