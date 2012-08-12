module settings;

import std.conv;
import common, ast, localization, interpreter;


final class Settings
{
    string rootPath;
    dstring language;
    RemarkTranslation remarkTranslation;

    static Settings load (string rootPath)
    {
        auto i = new Interpreter!DefaultInterpreterContext;
        auto env = i.interpret (rootPath ~ "/settings.gel");

        auto s = new Settings;
        s.rootPath = rootPath;
        s.language = (cast(AstText)env.get("language")).value;
        s.remarkTranslation = RemarkTranslation.load (rootPath, to!string(s.language));
        return s;
    }
}