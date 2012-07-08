module interpreter;

import std.stdio, std.algorithm, std.array, std.conv;
import ast;


@safe pure nothrow


final class Env
{
    this () { }

    this (Env parent)
    {
        this.parent = parent;
    }

    Env parent;

    IExp[string] values;
}


void interpret (AstFile file)
{
    auto env = new Env;

    initEnv (env, file.declarations);

    if ("start" in env.values)
        eval(env, env.values["start"]);
    else
        writeln ("No start function defined");

    //printEnv(env);
}


IExp eval (Env env, IExp exp)
{
    auto fn = cast (AstFn)exp;
    if (fn)
    {
        return evalFn(env, fn);
    }

    auto fnApply = cast (AstFnApply) exp;
    if (fnApply)
    {
        IExp[] eas;
        foreach (a; fnApply.args)
            eas ~= eval(env, a);

        if (fnApply.ident.ident == "print")
        {
            foreach (ea; eas)
                write(ea.toString());
            writeln();
            return null;
        }
        else
        {
            return evalFn(env, cast(AstFn)env.values[fnApply.ident.ident]);
        }
    }

    auto num = cast (AstNum) exp;
    if (num)
    {
        return num;
    }

    auto text = cast (AstText) exp;
    if (text)
    {
        return text;
    }

    auto ch = cast (AstChar) exp;
    if (ch)
    {
        return ch;
    }

    return null;
}


IExp evalFn (Env env, AstFn fn)
{
    int[string] labelIndex;
    auto c = 0;
    while (c < fn.fnItems.length)
    {
        auto fnItem = fn.fnItems[c];

        auto i = cast (AstIf)fnItem;
        if (i)
        {

            continue;
        }

        auto l = cast (AstLabel)fnItem;
        if (l)
        {
            labelIndex[l.label] = c;
            continue;
        }

        auto g = cast (AstGoto)fnItem;
        if (g)
        {
            c = labelIndex[l.label];
            continue;
        }

        auto r = cast (AstReturn)fnItem;
        if (r)
        {
            return r.exp;
        }

        auto e = cast (IExp) fnItem;
        if (e)
        {
            auto res = eval(env, e);
            if (fn.fnItems.length == 1)
                return res;
        }

        ++c;
    }

    return null;
}


void initEnv (Env env, AstDeclr[] declarations)
{
    foreach (d; declarations)
    {
        auto ident = d.ident.toString();
        if (ident in env.values)
            throw new Exception ("Variable " ~ ident ~ " is already declared");
        env.values[ident] = d.value;
        auto s = cast(AstStruct)d.value;
        if (s)
        {
            s.env = new Env(env);
            initEnv(s.env, s.declarations);
        }
    }
}

void printEnv (Env env, int level = 0)
{
    foreach (k, v; env.values)
    {
        writeln ("  ".replicate(level), k, " = ", v is null ? "<null>" : typeid(v).name);
        auto s = cast(AstStruct)v;if (s)
        {
            ++level;
            printEnv(s.env, level);
            --level;
        }
    }
}
