module settings;

import std.array, std.conv, std.file, std.utf;
import common, localization, parse.ast, validate.remarks,
    validate.validation, parse.parser;



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

        immutable src = toUTF32(readText(rootPath ~ "/settings.gel"));
        auto f = (new Parser(icontext, src)).parseAll();

        foreach (e; f.exps)
        {
            auto d = cast(AstDeclr)e;
            if (d.ident.idents[0] == "language")
                s.language = (cast(AstText)d.value).value;
            if (d.ident.idents[0] == "remarkLevelName")
                s.remarkLevelName = (cast(AstText)d.value).value;
        }

        s.remarkTranslation = RemarkTranslation.load (icontext, rootPath, to!string(s.language));
        s.remarkLevel = RemarkLevel.load (icontext, rootPath, to!string(s.remarkLevelName));

        return s;
    }
}

private @property dstring txtval (Exp e)
{
    return (cast(AstText)e).value;
}