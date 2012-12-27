module interpret.NameFinder;

import std.algorithm, std.conv;
import common, syntax.ast, validate.remarks, interpret.builtins;


@safe:


final class NameFinder : IAstVisitor!void
{
    nothrow:


    IValidationContext context;

    this (IValidationContext context) { this.context = context; }



    void visit (ValueStruct s)
    {
        foreach (e; s.exps)
            e.findName(this);
    }


    void visit (ValueFn fn)
    {
        foreach (p; fn.params)
            visit(p);

        foreach (e; fn.exps)
            e.findName(this);
    }


    void visit (ExpIdent i)
    {
        i.declaredBy = i.parent.get(i);

        if (!i.declaredBy)
        {
            auto bfn = i.text in builtinFns;
            if (bfn)
                i.declaredBy = *bfn;
        }
    }


    void visit (ExpFnApply fna)
    {
        fna.applicable.findName(this);

        foreach (a; fna.args)
            a.findName(this);
    }


    void visit (ExpIf i)
    {        
        i.when.findName(this);

        foreach (t; i.then)
            t.findName(this);

        foreach (o; i.otherwise)
            o.findName(this);
    }


    void visit (ExpDot d)
    { 
        d.record.findName(this);

        // d.member.declaredBy is assigned in the TypeInferer
    }


    @trusted void visit (ExpAssign a)
    {
        if (a.type)
            a.type.findName(this);

        if (a.value)
            a.value.findName(this);

        auto i = cast(ExpIdent)a.slot;
        auto declr = i.text in a.parent.declrs;
        if (declr)
        {
            auto declrIdent = cast(ExpIdent)declr.slot;
          //  i.closureItemIndex =  declrIdent.closureItemIndex;
        }
        else
        {
            a.parent.declrs[i.text] = a;
           // i.closureItemIndex =  env.closureItemIndex;
           // ++env.closureItemIndex;
        }
    }


    void visit (StmReturn r) { r.exp.findName(this); }

    void visit (Closure) { }

    void visit (StmLabel) { }
    void visit (StmGoto) { }

    void visit (ValueBuiltinFn) { }
    void visit (ValueUnknown) { }

    void visit (ValueInt) { }
    void visit (ValueFloat) { }
    void visit (ValueText) { }
    void visit (ValueChar) { }
    void visit (ValueArray) { }

    void visit (TypeType) { }
    void visit (TypeAny) { }
    void visit (TypeVoid) { }
    void visit (TypeOr) { }
    void visit (TypeFn) { }
    void visit (TypeInt) { }
    void visit (TypeFloat) { }
    void visit (TypeText) { }
    void visit (TypeChar) { }
    void visit (TypeStruct) { }
    void visit (TypeArray) { }

    void visit (WhiteSpace) { }
}