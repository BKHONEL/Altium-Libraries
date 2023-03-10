{..............................................................................}
{ Summary   This scripts can be used to show or hide layers.                   }
{                                                                              }
{           it shows all layers in a form and by clicking you turn them on or  }
{           off. This is easier to use than "Board Layers and colors" dialog   }
{           because:                                                           }
{           - View is automativally updated and user can see the view when     }
{             clicking on checkboxes, so if something also is in a way it can  }
{             be turned off                                                    }
{           - This is not dialog so user can control PCB while the form is     }
{             shown.                                                           }
{                                                                              }
{           Limitation - it supports "only" up to 32 signal layers. If you     }
{                        need more - ask.                                      }
{                                                                              }
{ Created by:    Petar Perisin                                                 }
{ Save position to ini file added by Tony Chilco 2011/12/14                    }
{ Tab object resize with main dialogue added by Tony Chilco 2011/12/14         }
{..............................................................................}

{..............................................................................}
var
   Board           : IPCB_Board;
   TheLayerStack   : IPCB_LayerStack;
   CB2LayerControl : Boolean;
   Refresh         : Boolean;
   CBClick         : Boolean;



function CBFromInt(i : Integer) : TCheckBox;
begin
   case i of
       1 : Result := CheckBox1;
       2 : Result := CheckBox2;
       3 : Result := CheckBox3;
       4 : Result := CheckBox4;
       5 : Result := CheckBox5;
       6 : Result := CheckBox6;
       7 : Result := CheckBox7;
       8 : Result := CheckBox8;
       9 : Result := CheckBox9;
      10 : Result := CheckBox10;
      11 : Result := CheckBox11;
      12 : Result := CheckBox12;
      13 : Result := CheckBox13;
      14 : Result := CheckBox14;
      15 : Result := CheckBox15;
      16 : Result := CheckBox16;
      17 : Result := CheckBox17;
      18 : Result := CheckBox18;
      19 : Result := CheckBox19;
      20 : Result := CheckBox20;
      21 : Result := CheckBox21;
      22 : Result := CheckBox22;
      23 : Result := CheckBox23;
      24 : Result := CheckBox24;
      25 : Result := CheckBox25;
      26 : Result := CheckBox26;
      27 : Result := CheckBox27;
      28 : Result := CheckBox28;
      29 : Result := CheckBox29;
      30 : Result := CheckBox30;
      31 : Result := CheckBox31;
      32 : Result := CheckBox32;
   end;
end;



function ShapeFromInt(i : Integer) : TShape;
begin
   case i of
       1 : Result := Shape1;
       2 : Result := Shape2;
       3 : Result := Shape3;
       4 : Result := Shape4;
       5 : Result := Shape5;
       6 : Result := Shape6;
       7 : Result := Shape7;
       8 : Result := Shape8;
       9 : Result := Shape9;
      10 : Result := Shape10;
      11 : Result := Shape11;
      12 : Result := Shape12;
      13 : Result := Shape13;
      14 : Result := Shape14;
      15 : Result := Shape15;
      16 : Result := Shape16;
      17 : Result := Shape17;
      18 : Result := Shape18;
      19 : Result := Shape19;
      20 : Result := Shape20;
      21 : Result := Shape21;
      22 : Result := Shape22;
      23 : Result := Shape23;
      24 : Result := Shape24;
      25 : Result := Shape25;
      26 : Result := Shape26;
      27 : Result := Shape27;
      28 : Result := Shape28;
      29 : Result := Shape29;
      30 : Result := Shape30;
      31 : Result := Shape31;
      32 : Result := Shape32;
   end;
end;



Procedure Layer2CB(CheckBox : TCheckBox, Tekst : String, Display : Boolean);
begin
   CheckBox.Enabled := True;
   CheckBox.Visible := True;
   CheckBox.Caption := Tekst;
   CheckBox.Checked := Display;
end;



Procedure CB2Layer(CheckBoxa : TCheckBox);
var
   LayerObj  : IPCB_LayerObject;
   MechLayer : IPCB_MechanicalLayer;
   i         : Integer;
begin

   if CB2LayerControl then
   begin
      if TabControlLayers.TabIndex = 0 then
      begin
         LayerObj := TheLayerStack.FirstLayer;
         while (LayerObj <> nil) do
         begin
            if LayerObj.Name = CheckBoxa.Caption then
            begin
               LayerObj.IsDisplayed[Board] := CheckBoxa.Checked;

               if Refresh and CheckBoxa.Checked then
                  Board.CurrentLayer := LayerObj.LayerID;

               break;
            end;
            LayerObj := TheLayerStack.NextLayer(LayerObj);
         end;
      end
      else if TabControlLayers.TabIndex = 1 then
      begin
         for i := 1 to 32 do
         begin
            MechLayer := TheLayerStack.LayerObject_V7[ILayer.MechanicalLayer(i)];

            if (MechLayer.MechanicalLayerEnabled) and (MechLayer.Name = CheckBoxa.Caption) then
            begin
               MechLayer.IsDisplayed[Board] := CheckBoxa.Checked;

               if Refresh and CheckBoxa.Checked then
                  Board.CurrentLayer := MechLayer.V7_LayerID;

               break;
            end;
         end;
      end
      else
      begin
         LayerObj := Board.LayerStack.LayerObject_V7[String2Layer(CheckBoxa.Caption)];

         LayerObj.IsDisplayed[Board] := CheckBoxa.Checked;

         if Refresh and CheckBoxa.Checked then
            Board.CurrentLayer := LayerObj.LayerID;
      end;

      if Refresh then
      begin
         Board.ViewManager_UpdateLayerTabs;
         Board.ViewManager_FullUpdate;
      end;
   end;
end;



Procedure OnLayerChange(dummy : String);
var
   LayerObj  : IPCB_LayerObject;
   MechLayer : IPCB_MechanicalLayer;
   i, j      : Integer;
   GetCB     : TCheckBox;
   Enabled   : Boolean;
   Disabled  : Boolean;
   Shape     : TShape;
begin
   CB2LayerControl := False;

   Enabled  := False;
   Disabled := False;

   if TabControlLayers.TabIndex = 0 then
   begin
      LayerObj := TheLayerStack.FirstLayer;
      i := 1;
      while (LayerObj <> nil) and (i <= 32) do
      begin
         if LayerObj.IsDisplayed[Board] then Enabled := True
         else                                Disabled := True;

         Layer2CB(CBFromInt(i),  LayerObj.Name, LayerObj.IsDisplayed[Board]);

         Shape := ShapeFromInt(i);
         Shape.Visible := True;
         Shape.Brush.Color := Board.LayerColor[LayerObj.LayerID];

         Inc(i);
         LayerObj := TheLayerStack.NextLayer(LayerObj);
      end;

      if Enabled = False then  CheckBoxAll.Checked := False;
      if Disabled = False then CheckBoxAll.Checked := True;

      While i <= 32 do
      begin
         GetCB := CBFromInt(i);
         if (i > 15) and (GetCB.Visible = False) then break;
         GetCB.Checked := False;
         GetCB.Enabled := False;
         GetCB.Visible := False;

         ShapeFromInt(i).Visible := False;
         Inc(i);
      end;
   end
   else if TabControlLayers.TabIndex = 1 then
   begin
      j := 0;
      for i := 1 to 32 do
      begin
         MechLayer := TheLayerStack.LayerObject_V7[ILayer.MechanicalLayer(i)];

         if MechLayer.MechanicalLayerEnabled then
         begin

            if MechLayer.IsDisplayed[Board] then Enabled := True
            else                                 Disabled := True;

            inc(j);
            Layer2CB(CBFromInt(j), MechLayer.Name, MechLayer.IsDisplayed[Board]);

            Shape := ShapeFromInt(j);
            Shape.Visible := True;

            Shape.Brush.Color := PCBServer.SystemOptions.LayerColors[MechLayer.V7_LayerID];
         end;
      end;

      if Enabled = False then  CheckBoxAll.Checked := False;
      if Disabled = False then CheckBoxAll.Checked := True;

      i := j + 1;

      While i <= 32 do
      begin
         GetCB := CBFromInt(i);
         if (i > 15) and (GetCB.Visible = False) then break;
         GetCB.Checked := False;
         GetCB.Enabled := False;
         GetCB.Visible := False;

         ShapeFromInt(i).Visible := False;
         Inc(i);
      end;
   end
   else
   begin
      // Here we take care of masks and other layers

      i := 3;

      While i <= 32 do
      begin
         GetCB := CBFromInt(i);
         if (i > 15) and (GetCB.Visible = False) then break;
         GetCB.Checked := False;
         GetCB.Enabled := False;
         GetCB.Visible := False;

         ShapeFromInt(i).Visible := False;

         if i < 15 then
            i := i + 3
         else
            Inc(i);
      end;

      Layer2CB(CheckBox1 , 'Multi Layer',        Board.LayerIsDisplayed[String2Layer('Multi Layer')]);
      Shape1.Visible := True;
      Shape1.Brush.Color := Board.LayerColor[String2Layer('Multi Layer')];

      Layer2CB(CheckBox2,  'Keep Out Layer',     Board.LayerIsDisplayed[String2Layer('Keep Out Layer')]);
      Shape2.Visible := True;
      Shape2.Brush.Color := Board.LayerColor[String2Layer('Keep Out Layer')];


      // Overlay
      Layer2CB(CheckBox4,  'Top Overlay',        Board.LayerIsDisplayed[String2Layer('Top Overlay')]);
      Shape4.Visible := True;
      Shape4.Brush.Color := Board.LayerColor[String2Layer('Top Overlay')];

      Layer2CB(CheckBox5,  'Bottom Overlay',     Board.LayerIsDisplayed[String2Layer('Bottom Overlay')]);
      Shape5.Visible := True;
      Shape5.Brush.Color := Board.LayerColor[String2Layer('Bottom Overlay')];


      // Masks
      Layer2CB(CheckBox7,  'Top Solder Mask',    Board.LayerIsDisplayed[String2Layer('Top Solder Mask')]);
      Shape7.Visible := True;
      Shape7.Brush.Color := Board.LayerColor[String2Layer('Top Solder Mask')];

      Layer2CB(CheckBox8,  'Bottom Solder Mask', Board.LayerIsDisplayed[String2Layer('Bottom Solder Mask')]);
      Shape8.Visible := True;
      Shape8.Brush.Color := Board.LayerColor[String2Layer('Bottom Solder Mask')];


      Layer2CB(CheckBox10, 'Top Paste',          Board.LayerIsDisplayed[String2Layer('Top Paste')]);
      Shape10.Visible := True;
      Shape10.Brush.Color := Board.LayerColor[String2Layer('Top Paste')];

      Layer2CB(CheckBox11, 'Bottom Paste',       Board.LayerIsDisplayed[String2Layer('Bottom Paste')]);
      Shape11.Visible := True;
      Shape11.Brush.Color := Board.LayerColor[String2Layer('Bottom Paste')];


      Layer2CB(CheckBox13, 'Drill Guide',        Board.LayerIsDisplayed[String2Layer('Drill Guide')]);
      Shape13.Visible := True;
      Shape13.Brush.Color := Board.LayerColor[String2Layer('Drill Guide')];

      Layer2CB(CheckBox14, 'Drill Drawing',      Board.LayerIsDisplayed[String2Layer('Drill Drawing')]);
      Shape14.Visible := True;
      Shape14.Brush.Color := Board.LayerColor[String2Layer('Drill Drawing')];


      i := 1;
      While i < 15 do
      begin
         GetCB := CBFromInt(i);
         if GetCB.Checked then Enabled := True
         else                  Disabled := True;

         inc(i);

         if ((i Mod 3) = 0) then Inc(i);

      end;

      if Enabled = False then  CheckBoxAll.Checked := False;
      if Disabled = False then CheckBoxAll.Checked := True;
   end;

   CB2LayerControl := True;
end;


procedure TShowHideLayers.TabControlLayersChange(Sender: TObject);
begin
   OnLayerChange('');
end;

procedure TShowHideLayers.ShowHideLayersShow(Sender: TObject);   
begin
   OnLayerChange('');


end;



procedure TShowHideLayers.CheckBoxAllClick(Sender: TObject);
var
   CB : TCheckBox;
   i  : Integer;
begin
   Refresh := True;

   if CB2LayerControl then
   begin
      for i := 1 to 32 do
      begin
         CB := CBFromInt(i);

         if CB.Visible then
         begin
            if CB.Checked <> CheckBoxAll.Checked then
               CB.Checked := CheckBoxAll.Checked;
         end
         else if TabControlLayers.TabIndex <> 2 then break
         else if i > 15 then break;

         if (TabControlLayers.TabIndex = 2) and (i = 3) then
            Refresh := True
         else
            Refresh := False;
      end;

      Board.ViewManager_UpdateLayerTabs;
      Board.ViewManager_FullUpdate;
   end;
   Refresh := True;
end;


Procedure CheckConditions(dummy : String);
var
   i        : Integer;
   Enabled  : Boolean;
   Disabled : Boolean;
   CB       : TCheckBox;
begin

   if CB2LayerControl then
   begin
      Enabled  := False;
      Disabled := False;

      for i := 1 to 32 do
      begin
         CB := CBFromInt(i);

         if CB.Visible then
         begin
            if CB.Checked then Enabled := True
            else               Disabled := True;
         end
         else if TabControlLayers.TabIndex < 2 then break
         else if i > 15 then break;
      end;

      CB2LayerControl := False;

      if Enabled  = False then
         CheckBoxAll.Checked := False;
      if Disabled = False then
         CheckBoxAll.Checked := True;

      CB2LayerControl := True;
   end;
end;



procedure TShowHideLayers.CheckBox1Click(Sender: TObject);
begin
   CB2Layer(CheckBox1);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox2Click(Sender: TObject);
begin
   CB2Layer(CheckBox2);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox3Click(Sender: TObject);
begin
   CB2Layer(CheckBox3);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox4Click(Sender: TObject);
begin
   CB2Layer(CheckBox4);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox5Click(Sender: TObject);
begin
   CB2Layer(CheckBox5);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox6Click(Sender: TObject);
begin
   CB2Layer(CheckBox6);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox7Click(Sender: TObject);
begin
   CB2Layer(CheckBox7);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox8Click(Sender: TObject);
begin
   CB2Layer(CheckBox8);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox9Click(Sender: TObject);
begin
   CB2Layer(CheckBox9);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox10Click(Sender: TObject);
begin
   CB2Layer(CheckBox10);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox11Click(Sender: TObject);
begin
   CB2Layer(CheckBox11);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox12Click(Sender: TObject);
begin
   CB2Layer(CheckBox12);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox13Click(Sender: TObject);
begin
   CB2Layer(CheckBox13);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox14Click(Sender: TObject);
begin
   CB2Layer(CheckBox14);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox15Click(Sender: TObject);
begin
   CB2Layer(CheckBox15);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox16Click(Sender: TObject);
begin
   CB2Layer(CheckBox16);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox17Click(Sender: TObject);
begin
   CB2Layer(CheckBox17);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox18Click(Sender: TObject);
begin
   CB2Layer(CheckBox18);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox19Click(Sender: TObject);
begin
   CB2Layer(CheckBox19);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox20Click(Sender: TObject);
begin
   CB2Layer(CheckBox20);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox21Click(Sender: TObject);
begin
   CB2Layer(CheckBox21);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox22Click(Sender: TObject);
begin
   CB2Layer(CheckBox22);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox23Click(Sender: TObject);
begin
   CB2Layer(CheckBox23);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox24Click(Sender: TObject);
begin
   CB2Layer(CheckBox24);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox25Click(Sender: TObject);
begin
   CB2Layer(CheckBox25);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox26Click(Sender: TObject);
begin
   CB2Layer(CheckBox26);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox27Click(Sender: TObject);
begin
   CB2Layer(CheckBox27);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox28Click(Sender: TObject);
begin
   CB2Layer(CheckBox28);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox29Click(Sender: TObject);
begin
   CB2Layer(CheckBox29);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox30Click(Sender: TObject);
begin
   CB2Layer(CheckBox30);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox31Click(Sender: TObject);
begin
   CB2Layer(CheckBox31);
   CheckConditions('');
end;

procedure TShowHideLayers.CheckBox32Click(Sender: TObject);
begin
   CB2Layer(CheckBox32);
   CheckConditions('');
end;



Procedure WriteToIniFile(AFileName : String);
Var
    IniFile : TIniFile;
Begin
    IniFile := TIniFile.Create(AFileName);

    IniFile.WriteInteger('Window', 'DialogueTop',    ShowHideLayers.Top);
    IniFile.WriteInteger('Window', 'DialogueHeight', ShowHideLayers.Height);
    IniFile.WriteInteger('Window', 'DialogueLeft',   ShowHideLayers.Left);
    IniFile.WriteInteger('Window', 'DialogueWidth',  ShowHideLayers.Width);
    IniFile.WriteInteger('Tabs',   'Current',        TabControlLayers.TabIndex);

    IniFile.Free;
End;



procedure TShowHideLayers.ShowHideLayersClose(Sender: TObject; var Action: TCloseAction);
begin
     WriteToIniFile(ClientAPI_SpecialFolder_AltiumApplicationData + '\ShowHideLayersScriptData.ini');
end;



procedure TShowHideLayers.ShowHideLayersResize(Sender: TObject);
begin
  TabControlLayers.Width:= ShowHideLayers.Width - 30;
  TabControlLayers.Height:= ShowHideLayers.Height - 50;
end;


Procedure Start;
var
    IniFile : TIniFile;
begin
   Board := PCBServer.GetCurrentPCBBoard;
   if Board = nil then exit;

   TheLayerStack := Board.LayerStack;
   if TheLayerStack = nil then exit;

   CB2LayerControl := True;
   Refresh := True;

   IniFile := TIniFile.Create(ClientAPI_SpecialFolder_AltiumApplicationData + '\ShowHideLayersScriptData.ini');

   TabControlLayers.TabIndex := IniFile.ReadInteger('Tabs',   'Current',        TabControlLayers.TabIndex);

   ShowHideLayers.Show;

   ShowHideLayers.Top        := IniFile.ReadInteger('Window', 'DialogueTop',    ShowHideLayers.Top);
   ShowHideLayers.Height     := IniFile.ReadInteger('Window', 'DialogueHeight', ShowHideLayers.Height);
   ShowHideLayers.Left       := IniFile.ReadInteger('Window', 'DialogueLeft',   ShowHideLayers.Left);
   ShowHideLayers.Width      := IniFile.ReadInteger('Window', 'DialogueWidth',  ShowHideLayers.Width);

   IniFile.Free;
end;
