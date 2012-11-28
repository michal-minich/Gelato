module settings;

import std.conv;
import common, syntax.ast, validate.remarks, syntax.SyntaxValidator, syntax.Parser;



final class LoadSettingsValidationContext : IValidationContext
{
    private IValidationContext base;

    this (IValidationContext base) { this.base = base; }

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

        auto loadContext = new LoadSettingsValidationContext(icontext);

        auto f = parseFile(loadContext, rootPath ~ "/settings.gel");

        foreach (e; f.exps)
        {
            auto d = cast(ExpAssign)e;
            auto i = cast(ExpIdent)d.slot;
            if (i.text == "language")
                s.language = (cast(ValueText)d.value).value;
            if (i.text == "remarkLevelName")
                s.remarkLevelName = (cast(ValueText)d.value).value;
        }

        s.remarkTranslation = RemarkTranslation.load (loadContext, rootPath, to!string(s.language));
        s.remarkLevel = RemarkLevel.load (loadContext, rootPath, to!string(s.remarkLevelName));

        return s;
    }
}