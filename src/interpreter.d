module interpreter;

import std.stdio, std.algorithm, std.array, std.conv, std.string, std.file, std.utf;
import common, ast, remarks, parser, validation;


interface IInterpreterContext : IValidationContext
{
    void print (dstring);

    void println ();

    void println (dstring);
}


final class Interpreter
{
    IInterpreterContext context;

    final class Env
    {
        private Env parent;
        Exp[dstring] values;

        this () { }
        this (Env parent) { this.parent = parent; }

        Exp get (dstring key)
        {
            if (auto v = key in values)
                return eval(this, *v);
            else if (parent)
                return eval(this, parent.get(key));
            else
                throw new Exception ("Variable " ~ key.to!string() ~ " is not declared.");
        }
    }


    Env interpret (IInterpreterContext icontext, string filePath)
    {
        immutable src = toUTF32(readText!string(filePath));
        return interpret(icontext, src);
    }


    Env interpret (IInterpreterContext icontext, dstring src)
    {
        auto ast = (new Parser(icontext, src)).parseAll();
        auto astFile = new AstFile(null, ast.map!(e => cast(AstDeclr)e)().array());
        auto v = new Validator(icontext);
        v.validate(astFile);
        return interpret(icontext, astFile);
    }


    Env interpret (IInterpreterContext icontext, AstFile file)
    {
        context = icontext;
        auto env = new Env;
        initEnv (env, file.declarations);

        if (auto s = "start"d in env.values)
            evalLambda(cast (AstLambda)*s, null);
        else
            context.remark (MissingStartFunction(null));

        return env;
    }


    private void initEnv (Env env, AstDeclr[] declarations)
    {
        foreach (d; declarations)
            setEnv (env, d);

        foreach (d; declarations)
            getIdentEnv(env, d.ident.idents).values[d.ident.idents[$ - 1]] = eval (env, d.value);

    }


    private Env getIdentEnv (Env env, dstring[] idents)
    {
        if (idents.length == 1)
            return env;
        else
        {
            auto l = cast(AstLambda)env.get(idents[0]);
            if (l)
                return getIdentEnv (l.env, idents[1 .. $]);
            else
                assert (false, to!string(idents[0]) ~ " has no members");
        }
    }


    private void setEnv (Env env, AstDeclr d)
    {
        env = getIdentEnv(env, d.ident.idents);
        auto ident = d.ident.idents[$ - 1];
        if (ident in env.values)
            throw new Exception ("Variable " ~ to!string(ident) ~ " is already declared.");
        env.values[ident] = d.value;
    }


    private void printEnv (Env env, int level = 0)
    {
        foreach (k, v; env.values)
            context.println("."d.replicate(level) ~ k ~ " = " ~
                    (v is null ? "<null>" : v.str(fv).splitLines()[0]));

        if (env.parent)
            printEnv(env.parent, ++level);
    }


    private Exp eval (Env env, Exp exp)
    {
        auto fn = cast (AstFn)exp;
        if (fn)
            return new AstLambda (new Env (env), fn);

        auto ident = cast (AstIdent)exp;
        if (ident)
            return getIdentEnv(env, ident.idents).get(ident.idents[$ - 1]);

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
                auto f = new AstFn (null, null, when.value == "0" ? i.otherwise : i.then);
                auto l = new AstLambda (new Env(env), f);
                return evalLambda (l, null);
            }
        }

        return exp;
    }


    private Exp evalFnApply (Env env, AstFnApply fnApply)
    {
        Exp[] eas;
        foreach (a; fnApply.args)
            eas ~= eval(env, a);

        if (fnApply.ident.idents[0] == "print")
        {
            foreach (ea; eas)
            {
                const txt = cast(AstText)ea;
                context.print(txt ? txt.value : ea.str(fv));
            }
            context.println();
            return null;
        }
        else if (fnApply.ident.idents[0] == "printEnv")
        {
            printEnv (env);
            return null;
        }
        else
        {
            return evalLambda(cast(AstLambda)getIdentEnv(env, fnApply.ident.idents)
                .get(fnApply.ident.idents[$ -1]), eas);
        }
    }


    private Exp evalLambda (AstLambda lambda, Exp[] args)
    {
        lambda = new AstLambda (new Env (lambda.env), lambda.fn);

        int[dstring] labelIndex;

        foreach (argIx, a; args)
        {
            auto idns = lambda.fn.params[argIx].ident.idents;
            getIdentEnv(lambda.env, idns).values[idns[$ - 1]] = a;
        }

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

            if (lambda.fn.fnItems.length == 1)
                return eval(lambda.env, fnItem);
            else
                eval(lambda.env, fnItem);
        }

        return null;
    }
}