// Welcome to your new AL extension.
// Remember that object names and IDs should be unique across all extensions.
// AL snippets start with t*, like tpageext - give them a try and happy coding!


pageextension 50110 InventoryPostSetup extends "Inventory Posting Setup"
{
    layout
    {
        addafter("Inventory Account (Interim)")
        {
            field("Accrued Revenue"; Rec."Accrued Revenue")
            {
                ApplicationArea = Basic, Suite;
                ToolTip = 'Specifies the number of the general ledger account to which to post transactions with the expected revenue for items in this combination.';
            }
        }
    }
}

pageextension 50111 SalesOrderExt extends "Sales Order"
{

}

tableextension 50110 InvPostSetup extends "Inventory Posting Setup"
{

    fields
    {

        field(50100; "Accrued Revenue"; Code[20])
        {
            Caption = 'Accrued Revenue Account';
            TableRelation = "G/L Account";
        }
    }
}

codeunit 50100 SalesPostRoutine
{
    Permissions = tabledata 17 = rimd;
    [EventSubscriber(ObjectType::Page, Page::"Sales Order", 'OnPostOnAfterSetDocumentIsPosted', '', false, false)]
    local procedure OnPostOnAfterSetDocumentIsPosted(SalesHeader: Record "Sales Header")
    var
        PstdSalesShip: Record "Sales Shipment Header";
        ItemLedgEntry: Record "Item Ledger Entry";
        Item: Record Item;
        InvPostSetup: Record "Inventory Posting Setup";
        ValueEntry: Record "Value Entry";
        GenLedgEntry: Record "G/L Entry";
        GenLedgEntry2: Record "G/L Entry";
        GenLedgAcc: Record "G/L Account";
        TotalExpRev: Decimal;
        AccRevCode: Code[20];
    begin
        Commit;
        if SalesHeader.Ship then begin
            TotalExpRev := 0;
            PstdSalesShip.Reset;
            PstdSalesShip.SetRange("Order No.", SalesHeader."No.");
            PstdSalesShip.SetRange("Posting Date", SalesHeader."Posting Date");
            if PstdSalesShip.FindFirst() then begin
                ItemLedgEntry.Reset;
                ItemLedgEntry.SetRange("Entry Type", ItemLedgEntry."Entry Type"::Sale);
                ItemLedgEntry.SetRange("Document Type", ItemLedgEntry."Document Type"::"Sales Shipment");
                ItemLedgEntry.SetRange("Document No.", PstdSalesShip."No.");
                ItemLedgEntry.SetRange("Posting Date", PstdSalesShip."Posting Date");
                if ItemLedgEntry.FindFirst() then
                    repeat
                        if Item.Get(ItemLedgEntry."Item No.") then begin
                            if InvPostSetup.Get(ItemLedgEntry."Location Code", Item."Inventory Posting Group") then begin
                                if InvPostSetup."Accrued Revenue" <> '' then
                                    AccRevCode := InvPostSetup."Accrued Revenue";
                                ValueEntry.Reset;
                                ValueEntry.SetRange("Item Ledger Entry No.", ItemLedgEntry."Entry No.");
                                if ValueEntry.FindFirst() then
                                    repeat
                                        TotalExpRev := TotalExpRev + ValueEntry."Sales Amount (Expected)";
                                    until ValueEntry.Next() = 0;
                            end;
                        end;

                    until ItemLedgEntry.Next() = 0;

                GenLedgEntry.Reset;
                GenLedgEntry.LockTable();
                if GenLedgEntry.FindLast() then begin
                    if GenLedgAcc.Get(AccRevCode) then begin
                        GenLedgEntry.Init();
                        GenLedgEntry."Entry No." := GenLedgEntry.GetLastEntryNo() + 1;
                        GenLedgEntry."G/L Account No." := GenLedgAcc."No.";
                        GenLedgEntry."G/L Account Name" := GenLedgAcc.Name;
                        GenLedgEntry."Document No." := PstdSalesShip."No.";
                        GenLedgEntry."Source Code" := 'SALES';
                        GenLedgEntry."Source Type" := GenLedgEntry."Source Type"::Customer;
                        GenLedgEntry."Source No." := PstdSalesShip."Bill-to Customer No.";
                        GenLedgEntry.Description := 'Shipment ' + PstdSalesShip."No.";
                        GenLedgEntry."Posting Date" := PstdSalesShip."Posting Date";
                        GenLedgEntry.Amount := TotalExpRev;
                        GenLedgEntry."Debit Amount" := TotalExpRev;
                        GenLedgEntry."User ID" := UserId;
                        GenLedgEntry.Insert();
                    end;
                end;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post (Yes/No)", 'OnAfterConfirmPost', '', false, false)]
    local procedure OnAfterConfirmPost(SalesHeader: Record "Sales Header")
    var
        PstdSalesShip: Record "Sales Shipment Header";
        ItemLedgEntry: Record "Item Ledger Entry";
        Item: Record Item;
        InvPostSetup: Record "Inventory Posting Setup";
        ValueEntry: Record "Value Entry";
        GenLedgEntry: Record "G/L Entry";
        GenLedgEntry2: Record "G/L Entry";
        GenLedgAcc: Record "G/L Account";
        TotalExpRev: Decimal;
        AccRevCode: Code[20];
    begin
        if SalesHeader.Invoice then begin
            PstdSalesShip.Reset;
            PstdSalesShip.SetRange("Order No.", SalesHeader."No.");
            if PstdSalesShip.FindFirst() then begin
                GenLedgEntry2.Reset;
                GenLedgEntry2.SetRange("Document No.", PstdSalesShip."No.");
                if GenLedgEntry2.FindFirst() then begin
                    if GenLedgEntry2.Count() = 1 then begin
                        GenLedgEntry.Reset;
                        GenLedgEntry.LockTable();
                        InvPostSetup.Reset;
                        InvPostSetup.SetFilter("Accrued Revenue", '<>%1', '');
                        iF InvPostSetup.FindFirst() then begin
                            AccRevCode := InvPostSetup."Accrued Revenue";
                            if GenLedgEntry.FindLast() then begin
                                if GenLedgAcc.Get(AccRevCode) then begin
                                    GenLedgEntry.Init();
                                    GenLedgEntry."Entry No." := GenLedgEntry.GetLastEntryNo() + 1;
                                    GenLedgEntry."G/L Account No." := GenLedgAcc."No.";
                                    GenLedgEntry."G/L Account Name" := GenLedgAcc.Name;
                                    GenLedgEntry."Document No." := PstdSalesShip."No.";
                                    GenLedgEntry."Source Code" := 'SALES';
                                    GenLedgEntry."Source Type" := GenLedgEntry."Source Type"::Customer;
                                    GenLedgEntry."Source No." := PstdSalesShip."Bill-to Customer No.";
                                    GenLedgEntry.Description := 'Shipment ' + PstdSalesShip."No.";
                                    GenLedgEntry."Posting Date" := PstdSalesShip."Posting Date";
                                    GenLedgEntry.Amount := GenLedgEntry2.Amount * -1;
                                    GenLedgEntry."Credit Amount" := GenLedgEntry2.Amount;
                                    GenLedgEntry."User ID" := UserId;
                                    GenLedgEntry.Insert();
                                end;
                            end;

                        end;
                    end;
                end;
            end;
        end;

    end;


}





