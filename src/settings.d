module settings;

import std.conv;
import common, ast, localization, remarks, interpreter;


final class Settings
{
    string rootPath;
    IInterpreterContext icontext;

    dstring language;
    RemarkTranslation remarkTranslation;

    dstring remarkLevelName;
    RemarkLevel remarkLevel;


    @property static Settings beforeLoad ()
    {
        auto s = new Settings;
        s.remarkTranslation = new RemarkTranslation;
        s.remarkLevel = new RemarkLevel;
        return s;
    }


    static Settings load (IInterpreterContext icontext, string rootPath)
    {
        auto s = new Settings;

        auto env = (new Interpreter).interpret (icontext, rootPath ~ "/settings.gel");

        s.rootPath = rootPath;
        s.icontext = icontext;

        s.language = env.get("language").txtval;
        s.remarkLevelName = env.get("remarkLevelName").txtval;

        s.remarkTranslation = RemarkTranslation.load (icontext, rootPath, to!string(s.language));
        s.remarkLevel = RemarkLevel.load (icontext, rootPath, to!string(s.remarkLevelName));

        return s;
    }
}

private @property dstring txtval (Exp e)
{
    return (cast(AstText)e).value;
}