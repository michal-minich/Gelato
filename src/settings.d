module settings;

import std.array, std.algorithm, std.conv;
import common, ast, interpreter;


final class Settings
{
    string rootPath;
    dstring language;

    static Settings load (string rootPath)
    {
        auto i = new Interpreter!DefaultInterpreterContext;
        auto env = i.interpret (rootPath ~ "/settings.gel");

        auto s = new Settings;
        s.rootPath = rootPath;
        s.language = env.get("language").str;
        return s;
    }
}