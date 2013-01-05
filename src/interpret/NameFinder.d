module interpret.NameFinder;

import std.algorithm, std.conv;
import common, syntax.ast, validate.remarks;


@safe:


final class NameFinder : INothrowAstVisitor!void
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


    void visit (ExpFnApply fna)
    {
        fna.applicable.findName(this);

        foreach (a; fna.args)
            a.findName(this);
    }


    void visit (ExpIf i)
    {        
        i.when.findName(this);

        foreach (t; i.then.exps)
            t.findName(this);

        foreach (o; i.otherwise.exps)
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
            i.closureItemIndex =  declrIdent.closureItemIndex;
        }
        else
        {
            a.isDeclr = true;
            a.parent.declrs[i.text] = a;
            i.closureItemIndex =  i.parent.closureItemsCount;
            ++i.parent.closureItemsCount;
        }
    }



    void visit (ExpIdent i)  { }

    void visit (StmReturn r) { r.exp.findName(this); }

    void visit (StmImport im) { im.exp.findName(this); }

    void visit (Closure) { }

    void visit (StmLabel) { }
    void visit (StmGoto) { }
    void visit (StmThrow) { }

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