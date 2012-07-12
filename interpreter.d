module interpreter;

import std.stdio, std.algorithm, std.array, std.conv, std.string;
import ast;


final class Env
{
    Env parent;
    IExp[string] values;

    this () { }
    this (Env parent) { this.parent = parent; }

    IExp get (string key)
    {
        if (auto v = key in values)
            return eval(this, *v);
        else if (parent)
            return eval(this, parent.get(key));
        else
            throw new Exception ("Variable " ~ key ~ " is not declared.");
    }
}


final class Lambda : IExp
{
    Env env;
    AstFn fn;

    this (Env e, AstFn f) { env = e; fn = f; }

    override string toString () { return fn.toString(); }
}


void interpret (AstFile file)
{
    auto env = new Env;
    initEnv (env, file.declarations);

    if ("start" in env.values)
        evalLambda(cast (Lambda)env.values["start"], null);
    else
        writeln ("No start function is defined.");
}


void initEnv (Env env, AstDeclr[] declarations)
{
    foreach (d; declarations)
        setEnv (env, d);

    foreach (d; declarations)
        env.values[d.ident.ident] = eval (env, d.value);
}


void setEnv (Env env, AstDeclr declaration)
{
    auto ident = declaration.ident.ident;
    if (ident in env.values)
        throw new Exception ("Variable " ~ ident ~ " is already declared.");
    env.values[ident] = declaration.value;
}


void printEnv (Env env, int level = 0)
{
    foreach (k, v; env.values)
        writeln(".".replicate(level), k, " = ",
                v is null ? "<null>" : v.toString().splitLines()[0]);

    if (env.parent)
        printEnv(env.parent, ++level);
}


IExp eval (Env env, IExp exp)
{
    auto fn = cast (AstFn)exp;
    if (fn)
        return new Lambda (new Env (env), fn);

    auto ident = cast (AstIdent)exp;
    if (ident)
        return env.get(ident.ident);

    auto fa = cast (AstFnApply)exp;
    if (fa)
        return evalFnApply (env, fa);

    auto i = cast (AstIf)exp;
    if (i)
    {
        auto when = cast(AstNum)eval(env, i.when);
        if (!when)
            throw new Exception ("if expression must evalute to number.");

        if (when.value == "0" && i.otherwise is null)
        {
            return null;
        }
        else
        {
            auto f = new AstFn;
            f.fnItems = when.value == "0" ? i.otherwise : i.then;
            auto l = new Lambda (new Env(env), f);
            return evalLambda (l, null);
        }
    }

    return exp;
}


IExp evalFnApply (Env env, AstFnApply fnApply)
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
    else if (fnApply.ident.ident == "printEnv")
    {
        printEnv (env);
        return null;
    }
    else
    {
        return evalLambda(cast(Lambda)env.get(fnApply.ident.ident), eas);
    }
}


IExp evalLambda (Lambda lambda, IExp[] args)
{
    lambda = new Lambda (new Env (lambda.env), lambda.fn);

    int[string] labelIndex;

    foreach (argIx, a; args)
        lambda.env.values[lambda.fn.params[argIx].ident.ident] = a;

    auto c = 0;
    while (c < lambda.fn.fnItems.length)
    {
        auto fnItem = lambda.fn.fnItems[c];
        ++c;

        auto d = cast (AstDeclr)fnItem;
        if (d)
        {
            d.value = eval (lambda.env, d.value);
            setEnv (lambda.env, d);
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
            return eval(lambda.env, r.exp);
        }

        auto e = cast (IExp)fnItem;
        if (e)
        {
            if (lambda.fn.fnItems.length == 1)
                return eval(lambda.env, e);
            else
                eval(lambda.env, e);
        }
    }

    return null;
}
