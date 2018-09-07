/+
                      Copyright 0xEAB 2018
     Distributed under the Boost Software License, Version 1.0.
        (See accompanying file LICENSE_1_0.txt or copy at
              https://www.boost.org/LICENSE_1_0.txt)
 +/
module linedubbed.database;

import std.conv : to;
import std.range : isInputRange, ElementType;

import arsd.sqlite;
import linedubbed.registry : DUBPackage;
import linedubbed.tester : TestResult, TestStatus;

public
{
    alias Database = Sqlite;
}

private
{
    enum dbLayout = `
CREATE TABLE IF NOT EXISTS packages(
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS builds(
    id INTEGER PRIMARY KEY,
    packages_id INTEGER REFERENCES packages(id) NOT NULL,
    version TEXT NOT NULL,
    compiler TEXT NOT NULL,
    success BOOLEAN NOT NULL,
    buildlog TEXT NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL
);`;
}

void commit(Database db)
{
    db.query("COMMIT;");
}

void rollback(Database db)
{
    db.query("ROLLBACK;");
}

Database openAndInitIfNotExists(string sqliteFile)
{
    return openDBAndCreateIfNotPresent(sqliteFile, dbLayout);
}

DUBPackage getDatabasePackageHandle(Database db, DUBPackage p)
{
    int id = void;
    ResultSet r = db.query("SELECT id FROM packages WHERE name = ?", p.name);

    if (r.empty)
    {
        db.query("INSERT INTO packages (name) VALUES(?)", p.name);
        id = db.lastInsertId;
    }
    else
    {
        id = r.front["id"].to!int;
    }

    p.databaseID = id;
    return p;
}

DUBPackage[] getDatabasePackageHandle(Range)(Database db, Range packages)
        if (isInputRange!Range && is(ElementType!Range == DUBPackage))
{
    db.startTransaction();
    scope (success)
        db.commit();
    scope (failure)
        db.rollback();

    DUBPackage[] output;
    foreach (p; packages)
    {
        output ~= db.getDatabasePackageHandle(p);
    }
    return output;
}

void saveTestResult(Database db, TestResult test)
{
    assert((test.status == TestStatus.success) || (test.status == TestStatus.failure));

    db.query("INSERT INTO builds (packages_id, version, compiler, success, buildlog) VALUES(?, ?, ?, ?, ?)",
            test.dubPackage.databaseID,
            test.dubPackage.version_, test.compiler.id,
            cast(int)(test.status == TestStatus.success), test.buildLog);
}

string getLatestTestedVersion(Database db, DUBPackage p)
{
    // FIXME: proper version comparison instead of db timestamp
    ResultSet r = db.query("SELECT version FROM builds WHERE timestamp = "
            ~ "(SELECT MAX(timestamp) FROM builds WHERE packages_id = ?)" ~ " AND packages_id = ?",
            p.databaseID, p.databaseID);

    if (r.empty)
    {
        return null;
    }

    return r.front["version"];
}
