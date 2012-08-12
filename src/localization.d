module localization;


import std.array, std.conv;
import common, ast, remarks, interpreter;


final class RemarkTranslation : IValidationTranslation
{
    private dstring[dstring] values;
    private string rootPath;
    private string inherit;
    private RemarkTranslation inherited;


    dstring textOf (const Remark remark)
    {
        immutable key = remark.code;

        if (!values.length)
            return remark.code;

        if (auto v = key in values)
            return *v;

        if (!inherited && inherit)
            inherited = load (sett.icontext, rootPath, inherit);

        if (inherited)
            return inherited.textOf (remark);

        assert (false, "no translation for " ~ to!string(remark.code));
    }


    static RemarkTranslation load (IInterpreterContext icontext, const string rootPath, const string language)
    {
        auto env = (new Interpreter)
            .interpret (icontext, rootPath ~ "/lang/" ~ language ~ "/settings.gel");

        auto rt = new RemarkTranslation;
        rt.rootPath = rootPath;

        if (auto v = "inherit"d in env.values)
            rt.inherit = (cast(AstText)*v).value.to!string();

        rt.values = loadValues (icontext, rootPath ~ "/lang/" ~ language ~ "/remarks.gel");

        return rt;
    }


    private static dstring[dstring] loadValues (IInterpreterContext icontext, const string filePath)
    {
        dstring[dstring] vals;
        auto env = (new Interpreter).interpret (icontext, filePath);
        foreach (k, v; env.values)
            vals[k.replace("_", "-")] = (cast(AstText)v).value;
        return vals;
    }
}