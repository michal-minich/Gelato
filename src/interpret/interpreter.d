module interpret.interpreter;

import std.algorithm, std.array, std.conv, std.string, std.file, std.utf;
import common, validate.remarks, validate.validation, parse.ast, parse.parser;


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
        auto f = (new Parser(icontext, src)).parseAll();
        auto v = new Validator(icontext);
        v.validate(f);
        return interpret(icontext, f);
    }


    Env interpret (IInterpreterContext icontext, AstFile file)
    {
        context = icontext;
        auto env = new Env;
        initEnv (env, file.exps);

        if (auto s = "start"d in env.values)
            evalLambda(cast (AstLambda)*s, null);
        else
            context.remark (MissingStartFunction(null));

        return env;
    }


    private void initEnv (Env env, Exp[] exps)
    {
        foreach (e; exps)
        {
            auto d = cast(AstDeclr)e;
            if (d)
                setEnv (env, d);
        }

        foreach (e; exps)
        {
            auto d = cast(AstDeclr)e;
            if (d)
                getIdentEnv(env, d.ident.idents).values[d.ident.idents[$ - 1]]
                    = eval (env, d.value);
        }

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
                auto f = new AstFn (null, null);
                f.exps = when.value == "0" ? i.otherwise : i.then;
                auto l = new AstLambda (new Env(env), f);
                return evalLambda (l, null);
            }
        }

        auto s = cast(AstStruct)exp;
        if (s)
        {
            auto f = new AstFn(s, s);
            foreach (e; s.exps)
            {
                auto id = cast(AstIdent)e;
                auto d = cast(AstDeclr)e;
                if (!id && !d)
                    assert (false, "struct can contain only declarations or identifiers");
                else
                    f.params ~= d ? d : new AstDeclr(s, s, id);
            }
            s.exps = null;
            f.exps ~= new AstFn (s, s);
            return new AstLambda(new Env(env), f);
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
            lambda.env.values[lambda.fn.params[argIx].ident.idents[0]] = a;

        foreach (p; lambda.fn.params[args.length .. $])
        {
            if (!p.value)
                assert (false, "parameter has not default value so arg must be specified");
            lambda.env.values[p.ident.idents[0]] = eval(lambda.env, p.value);
        }

        auto c = 0;
        while (c < lambda.fn.exps.length)
        {
            auto fnItem = lambda.fn.exps[c];
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

            if (lambda.fn.exps.length == 1)
                return eval(lambda.env, fnItem);
            else
                eval(lambda.env, fnItem);
        }

        return null;
    }
}