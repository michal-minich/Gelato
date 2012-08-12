module settings;

import std.conv;
import common, ast, localization, remarks, interpreter;


final class Settings
{
    string rootPath;

    dstring language;
    RemarkTranslation remarkTranslation;

    dstring remarkLevelName;
    RemarkLevel remarkLevel;

    static Settings load (string rootPath)
    {
        auto i = new Interpreter!DefaultInterpreterContext;
        auto env = i.interpret (rootPath ~ "/settings.gel");

        auto s = new Settings;
        s.rootPath = rootPath;

        s.language = env.get("language").txtval;
        s.remarkLevelName = env.get("remarkLevelName").txtval;

        s.remarkTranslation = RemarkTranslation.load (rootPath, to!string(s.language));
        s.remarkLevel = RemarkLevel.load (rootPath, to!string(s.remarkLevelName));

        return s;
    }
}

private @property dstring txtval (Exp e)
{
    return (cast(AstText)e).value;
}