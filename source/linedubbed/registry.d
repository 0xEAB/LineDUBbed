/+
                      Copyright 0xEAB 2018
     Distributed under the Boost Software License, Version 1.0.
        (See accompanying file LICENSE_1_0.txt or copy at
              https://www.boost.org/LICENSE_1_0.txt)
 +/
module linedubbed.registry;

import std.algorithm : map;
import std.json;
import std.net.curl : get;

private
{
    enum uriPackageList = "/api/packages/search";
}

auto getPackages(string registryURL)
{
    JSONValue list = get(registryURL ~ uriPackageList).parseJSON();
    return list.array.map!toDUBPackage;
}

DUBPackage toDUBPackage(JSONValue v)
{
    auto o = v.object;
    return DUBPackage(o["name"].str, o["version"].str, -1);
}

struct DUBPackage
{
    string name;
    string version_;
    int databaseID = -1;
}
