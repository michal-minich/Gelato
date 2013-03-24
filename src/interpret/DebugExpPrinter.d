module interpreter.DebugExpPrinter;


import std.conv, std.stdio;
import common, syntax.ast;


@trusted pure final class DebugExpPrinter : IAstVisitor!void
{
    private 
    {
        IPrinter printer;
        bool isFirstIdent = true;
    }

    nothrow this (IPrinter printer) { this.printer = printer; }

    void visit (ValueInt i) {  printer.println("ValueInt " ~ i.value.to!dstring()); }

    void visit (ValueFloat f) {  printer.println("ValueFloat " ~ f.value.to!dstring()); }

    void visit (ValueUnknown u) { printer.println("ValueUnknown " ~ (u.ident ? u.ident.to!dstring() : "")); }

    void visit (ExpAssign a)
    {
        printer.println("ExpAssign "d 
                        ~ (a.isVar ? "isVar "d : " ") 
                        ~ (a.isDeclr ? "isDeclr "d : " ")
                        ~ (!a.readBy ? "not-read "d : " ")
                        ~ (!a.writtenBy ? "not-written "d : " "));

        printer.print("  .slot ");
        a.slot.accept(this);
        
        if (a.type)
        {
            printer.print("  .type ");
            a.type.accept(this);
        }
        
        if (a.value)
        {
            printer.print("  .value ");
            a.value.accept(this);
        }

        if (a.readBy)
        {
            printer.print("  .readBy " ~ a.readBy.length.to!dstring() ~ " Lines: ");
            foreach (r; a.readBy)
                printer.print(r.tokens[0].start.line.to!dstring() ~ ", ");
        }

        if (a.writtenBy)
        {
            if (a.readBy)
                printer.println();

            printer.print("  .writtenBy " ~ a.writtenBy.length.to!dstring() ~ " Lines: ");
            foreach (w; a.writtenBy)
                printer.print(w.tokens[0].start.line.to!dstring() ~ ", ");
        }
    }

    void visit (ValueStruct e) { printer.println("ValueStruct"); }

    void visit (ValueArray e) { printer.println("ValueArray"); }

    void visit (ValueFn e) { printer.println("ValueFn"); }

    void visit (ExpFnApply e) { printer.println("ExpFnApply"); }

    void visit (ExpIdent i)
    {
        if (isFirstIdent)
        {
            if (i.declaredBy)
            {
                printer.print("ExpIdent + ");
                isFirstIdent = false;
                i.declaredBy.accept(this);
            }
        }
        else
        {
            printer.println("ExpIdent " ~ i.text);
        }
    }

    void visit (StmLabel e) { printer.println("StmLabel"); }

    void visit (StmReturn e) { printer.println("StmReturn"); }

    void visit (StmImport im) { printer.println("StmImport"); }

    void visit (StmThrow) { printer.println("StmThrow"); }

    void visit (ValueText e){  printer.println("ValueText"); printer.println(e.value); }

    void visit (ValueChar e) {  printer.println("ValueChar"); printer.println(e.value.to!dstring()); }

    void visit (ExpIf e) { printer.println("ExpIf"); }

    void visit (StmGoto e) { printer.println("StmGoto"); }

    void visit (Closure sc) { printer.println("Closure"); }

    void visit (ExpDot dot)
    { 
        if (dot.member.declaredBy)
        {
            printer.print("ExpDot + "); 
            dot.member.declaredBy.accept(this);
        }
        else
        {
            printer.println("ExpDot"); 
        }
    }

    void visit (TypeType tt) { printer.println("TypeType"); }

    void visit (TypeAny) { printer.println("TypeAny"); }

    void visit (TypeVoid) { printer.println("TypeVoid"); }

    void visit (TypeInt) { printer.println("TypeInt"); }

    void visit (TypeFloat) { printer.println("TypeFloat"); }

    void visit (TypeText) { printer.println("TypeText"); }

    void visit (TypeChar) { printer.println("TypeChar"); }

    void visit (TypeStruct) { printer.println("TypeStruct"); }

    void visit (ValueBuiltinFn) { printer.println("ValueBuiltinFn"); }

    void visit (TypeAnyOf tao) { printer.println("TypeAnyOf"); }

    void visit (TypeArray ta) { printer.println("TypeArray"); }

    void visit (TypeFn tfn) { printer.println("TypeFn"); }

    void visit (WhiteSpace ws) { printer.println("WhiteSpace"); }
}