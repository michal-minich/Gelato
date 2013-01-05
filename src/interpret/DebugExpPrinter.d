module interpreter.DebugExpPrinter;


import std.conv;
import common, syntax.ast;


@trusted pure final class DebugExpPrinter : IAstVisitor!void
{
    private 
    {
        IPrinterContext context;
        bool isFirstIdent = true;
    }

    nothrow this (IPrinterContext context) { this.context = context; }

    void visit (ValueInt i) {  context.println("ValueInt " ~ i.value.to!dstring()); }

    void visit (ValueFloat f) {  context.println("ValueFloat " ~ f.value.to!dstring()); }

    void visit (ValueUnknown u) { context.println("ValueUnknown " ~ (u.ident ? u.ident.to!dstring() : "")); }

    void visit (ExpAssign a)
    {
        context.println("ExpAssign "d 
                        ~ (a.isVar ? "isVar "d : " ") 
                        ~ (a.isDeclr ? "isDeclr "d : " ")
                        ~ (!a.readBy ? "not-read "d : " ")
                        ~ (!a.writtenBy ? "not-written "d : " "));

        context.print("  .slot ");
        a.slot.accept(this);
        
        if (a.type)
        {
            context.print("  .type ");
            a.type.accept(this);
        }
        
        if (a.value)
        {
            context.print("  .value ");
            a.value.accept(this);
        }

        if (a.readBy)
        {
            context.print("  .readBy " ~ a.readBy.length.to!dstring() ~ " Lines: ");
            foreach (r; a.readBy)
                context.print(r.tokens[0].start.line.to!dstring() ~ ", ");
        }

        if (a.writtenBy)
        {
            if (a.readBy)
                context.println();

            context.print("  .writtenBy " ~ a.writtenBy.length.to!dstring() ~ " Lines: ");
            foreach (w; a.writtenBy)
                context.print(w.tokens[0].start.line.to!dstring() ~ ", ");
        }
    }

    void visit (ValueStruct e) { context.println("ValueStruct"); }

    void visit (ValueArray e) { context.println("ValueArray"); }

    void visit (ValueFn e) { context.println("ValueFn"); }

    void visit (ExpFnApply e) { context.println("ExpFnApply"); }

    void visit (ExpIdent i)
    {
        if (isFirstIdent)
        {
            if (i.declaredBy)
            {
                context.print("ExpIdent + ");
                isFirstIdent = false;
                i.declaredBy.accept(this);
            }
        }
        else
        {
            context.println("ExpIdent " ~ i.text);
        }
    }

    void visit (StmLabel e) { context.println("StmLabel"); }

    void visit (StmReturn e) { context.println("StmReturn"); }

    void visit (StmThrow) { context.println("StmThrow"); }

    void visit (ValueText e){  context.println("ValueText"); context.println(e.value); }

    void visit (ValueChar e) {  context.println("ValueChar"); context.println(e.value.to!dstring()); }

    void visit (ExpIf e) { context.println("ExpIf"); }

    void visit (StmGoto e) { context.println("StmGoto"); }

    void visit (Closure sc) { context.println("Closure"); }

    void visit (ExpDot dot)
    { 
        if (dot.member.declaredBy)
        {
            context.print("ExpDot + "); 
            dot.member.declaredBy.accept(this);
        }
        else
        {
            context.println("ExpDot"); 
        }
    }

    void visit (TypeType tt) { context.println("TypeType"); }

    void visit (TypeAny) { context.println("TypeAny"); }

    void visit (TypeVoid) { context.println("TypeVoid"); }

    void visit (TypeInt) { context.println("TypeInt"); }

    void visit (TypeFloat) { context.println("TypeFloat"); }

    void visit (TypeText) { context.println("TypeText"); }

    void visit (TypeChar) { context.println("TypeChar"); }

    void visit (TypeStruct) { context.println("TypeStruct"); }

    void visit (ValueBuiltinFn) { context.println("ValueBuiltinFn"); }

    void visit (TypeOr tor) { context.println("TypeOr"); }

    void visit (TypeArray tor) { context.println("TypeArray"); }

    void visit (TypeFn tfn) { context.println("TypeFn"); }

    void visit (WhiteSpace ws) { context.println("WhiteSpace"); }
}