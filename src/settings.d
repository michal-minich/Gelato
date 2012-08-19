module settings;

import std.conv;
import common, localization, parse.ast, validate.remarks, validate.validation, interpret.interpreter;



final class LoadSettingsInterpreterContext : IInterpreterContext
{
    private IInterpreterContext base;

    this (IInterpreterContext base) { this.base = base; }

    void print (dstring str) { base.print (str); }

    void println () { base.println (); }

    void println (dstring str) { base.println (str); }

    void remark (Remark remark)
    {
        if (remark.code == "MissingStartFunction")
            return;

        base.remark(remark);
    }
}


final class Settings
{
    string rootPath;
    IInterpreterContext icontext;

    dstring language;
    IRemarkTranslation remarkTranslation;

    dstring remarkLevelName;
    IRemarkLevel remarkLevel;


    @property static Settings beforeLoad ()
    {
        auto s = new Settings;
        s.remarkTranslation = new NoRemarkTranslation;
        s.remarkLevel = new NoRemarkLevel;
        return s;
    }


    static Settings load (IInterpreterContext icontext, string rootPath)
    {
        auto s = new Settings;

        s.rootPath = rootPath;
        s.icontext = icontext;
/*
        auto env = (new Interpreter).interpret (icontext, rootPath ~ "/settings.gel");

        s.language = env.get("language").txtval;
        s.remarkLevelName = env.get("remarkLevelName").txtval;

        s.remarkTranslation = RemarkTranslation.load (icontext, rootPath, to!string(s.language));
        s.remarkLevel = RemarkLevel.load (icontext, rootPath, to!string(s.remarkLevelName));
*/
        return s;
    }
}

private @property dstring txtval (Exp e)
{
    return (cast(AstText)e).value;
}