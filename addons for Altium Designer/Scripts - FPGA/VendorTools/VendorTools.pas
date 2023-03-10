{..............................................................................}
{ Summary   This Script is made to help people working with FPGA vendor tools. }
{           It can import and export pin swap info for specific vendor.        }
{                                                                              }
{           Script should be executed by starting the "Start" procedure.       }
{                                                                              }
{           It then shows small dialog in which user should choose Vendor      }
{           tool, and choose weather he will do import or export.              }
{                                                                              }
{           It currently supports Altera, Lattice and Xilinx, but soon I will  }
{            try to support Actel (but I need help from Actel user for this).  }
{                                                                              }
{           - Altera  export generates .tcl file                               }
{           - Altera  import needs .pin file                                   }
{           - Xilinx  export generates .ucf file                               }
{           - Xilinx  import needs .ucf file                                   }
{           - Lattice export generates .csv file                               }
{           - Lattice import needs .pad file                                   }
{                                                                              }
{           Aditionally ther is custom import-export that works with simple    }
{           csv files that contain only "PinName, NetName" data. On import     }
{           data can be separated with '=', ',' or ';'                         }
{                                                                              }
{           Known issues (on import only):                                     }
{           - If you place wire stub shorter than the one already on the PCB,  }
{             maybe script will not be able to remove positioned netlabel.     }
{             But anyway, this netlabel will always be floating, so ERC        }
{             should catch it. This is very rare case. To avoid this best      }
{             practice is to use default value.                                }
{                                                                              }
{                                                                              }
{                                                                              }
{ Created by:    Petar Perisin                                                 }
{ Fixes from:    Claudio Veronesi                                              }
{                - Issue with Unconnected net labels on same coordinate        }
{                - Issue with Alternate part view                              }
{                                                                              }
{..............................................................................}

{..............................................................................}
var
   FlatHierarchy    : IDocument;
   SchDoc           : ISch_Document;
{..............................................................................}
{                                                                              }
{               PinInfo - main string list                                     }
{                                                                              }
{    This StringList contains all info about the pins.                         }
{    It is handled as a dictionary, and it holds info in "Name = Value" mode   }
{                                                                              }
{    Name of each entry is "PinName", and value is  "NetName"                  }
{                                                                              }
{    PinName1=NetName1                                                         }
{    PinName2=NetName2                                                         }
{    PinName3=NetName3                                                         }
{                                                                              }
{    if pin should be unconnected, his net name is: 'DoNotConnectOnSCH'        }
{..............................................................................}
   PinInfo       : TStringList;







// Two procedures to modify the form
procedure TVendorToolsForm.RadioButtonImportClick(Sender: TObject);
begin
   if RadioButtonImport.Checked then
      EditLength.Enabled := True
   else
      EditLength.Enabled := False;
end;



procedure TVendorToolsForm.RadioButtonExportClick(Sender: TObject);
begin
   if RadioButtonImport.Checked then
      EditLength.Enabled := True
   else
      EditLength.Enabled := False;
end;


// GetToken - Function that returns
function GetToken(Tekst : String, TokenNum: Integer, SepChar: String): string;

var
  Token: string;
  StringLen: Integer;
  Num: Integer;
  EndofToken: Integer;
  i: Integer;
begin
  {Delete multiple spaces}
  StringLen := Length(Tekst);

  Num := 1;
  EndofToken := StringLen;
  while ((Num <= TokenNum) and (EndofToken <> 0)) do
  begin
    EndofToken := Pos(SepChar, Tekst);
    if EndofToken <> 0 then
    begin
      Token := Copy(Tekst, 1, EndofToken - 1);
      Delete(Tekst, 1, EndofToken);
      Inc(Num);
    end
    else
      Token := Tekst;
  end;
  if Num >= TokenNum then
    Result := Token
  else
    Result := '';
end;


//Following function removes multiple and leading spaces
function RemoveMultipleSpaces(Tekst): string;

var
   i: Integer;
   StringLen: Integer;
begin
   if Tekst = '' then
   begin
      Result := '';
      exit;
   end;
   i:=0;
   StringLen := Length(Tekst);
   while i<=StringLen do
      if ((Tekst[i]=' ') And (Tekst[i+1]=' ')) then
         Delete(Tekst, i, 1)
      else
         Inc(i);
   Result := Trim(Tekst);
end;


// Get pin name from a PinInfo line
function GetPinName(Tekst : String): String;
var
   i : Integer;
   Temp : String;
Begin
   i := AnsiPos('=',Tekst);
   Temp := Tekst;

   if i > 0 then
      SetLength(Temp, i - 1);
   Result := Temp;
end;


// Get net name from a PinInfo line, that does not contain diff pair extension
// or a number for a bus
function GetNetText(Tekst : String): String;
var
   Len       : Integer;
   i         : Integer;
   AsciiCode : Integer;
   Temp      : String;
Begin
   i := AnsiPos('=',Tekst);
   Len := Length(Tekst);

   // Take everithing behind '=' sign
   if i > 0 then
      Temp :=  Copy(Tekst, i + 1, Len - i);

   //Now we need to remove index
   AsciiCode := ord(Temp[Length(Temp)]);

   // We need to check if we have number at the end
   while (AsciiCode > 47) and (AsciiCode < 58) do
   begin
      SetLength(Temp, Length(Temp) - 1);
      AsciiCode := ord(Temp[Length(Temp)]);
   end;

   // Now we need to check weather we have _P or _N at the end
   Len := Length(Temp);

   if (Temp[Len - 1] = '_') and ((Temp[Len] = 'P') or (Temp[Len] = 'N')) then
       SetLength(Temp, Len - 2);

   Result := Temp;
end;


// Get Net Index (number on a bus)
function GetNetIndex(Tekst : String): String;
var
   Len       : Integer;
   i         : Integer;
   Return    : String;
   AsciiCode : Integer;
Begin
   Len := Length(Tekst);
   Return := '';

   AsciiCode := ord(Tekst[Len]);

   // We need to check if we have number at the end
   while (AsciiCode > 47) and (AsciiCode < 58) do
   begin
      Len := Len - 1;
      AsciiCode := ord(Tekst[Len]);
   end;

   if (Len <> Length(Tekst)) then
       Return := Copy(Tekst, Len + 1, Length(Tekst) - Len);

   Result := Return;
end;


// Is net a diff pair
function IsDiffPair(Tekst : String): String;
var

   Len       : Integer;
   i         : Integer;
   Temp      : String;
   AsciiCode : Integer;

Begin
   Temp := Tekst;

   AsciiCode := ord(Temp[Length(Temp)]);

   // We need to check if we have number at the end
   while (AsciiCode > 47) and (AsciiCode < 58) do
   begin
      SetLength(Temp, Length(Temp) - 1);
      AsciiCode := ord(Temp[Length(Temp)]);
   end;

   // Now we need to check weather we have _P or _N at the end
   Len := Length(Temp);

   Result := 'None';

   if (Temp[Len - 1] = '_')then
   begin
      if      (Temp[Len] = 'P') or (Temp[Len] = 'p') then Result := 'Positive'
      else if (Temp[Len] = 'N') or (Temp[Len] = 'n') then Result := 'Negative';
   end;
end;


// Here we have functions that imports from vendor tools
Procedure ImportFromActel(extension : string);
begin
   close;
end;

Procedure ImportFromAltera(extension : string);
var
   i, j     : Integer;
   Flag     : Integer;
   FileName : String;
   PinFile  : TstringList;
   Line     : String;

   Indeks   : Integer;
   Name     : String;
   Value    : String;

   AsciiCode : Integer;
   PosValue  : String;

   TempLine : String;

begin

   SaveDialog.Title  := 'Import pin info from *.' + extension + ' file for Component ' + ComboBoxDesignator.Text;
   SaveDialog.Filter := AnsiUpperCase(extension) + ' file (*.' + extension + ')|*.' + extension;

   Flag := OpenDialog.Execute;
   if (not Flag) then exit;

   FileName := OpenDialog.FileName;

   PinFile := TStringList.Create;

   PinFile.LoadFromFile(Filename);

   i := 0;

   While i < PinFile.Count do
   begin
      Line := PinFile[i];
      Line := StringReplace(Line, Chr(9), ' ', MkSet(rfReplaceAll));
      Line := Trim(Line);

      if Line <> '' then
         if (Line[1] <> '-') then
            if (Length(Line) > 1) then
               if (Line[2] <> '-') then
                  if (Trim(GetToken(RemoveMultipleSpaces(Line), 1 ,':')) = 'Pin Name/Usage') then break;

      Inc(i);
   end;

   // Now 'i' contains a line where pin names start
   Inc(i);

   // We will be reading now
   While i < PinFile.Count do
   begin
      Line := PinFile[i];
      Line := RemoveMultipleSpaces(Line);

      if (Length(Line) > 1) then
         if (Line[1] <> '-') and (Line[2] <> '-') then
         begin
            Name := Trim(GetToken(Line,1,':'));
            if (Name = 'RESERVED_INPUT_WITH_WEAK_PULLUP') or (Name = 'RESERVED_INPUT') or (Name = 'RESERVED_INPUT_WITH_BUS_HOLD') or
               (Name = 'RESERVED') or (Name = 'RESERVED_OUTPUT_DRIVEN_HIGH') or (Name = 'NC')  or (Name = 'DNU') or (Name = 'GND*') then
                   Name := 'DoNotConnectOnSCH';

            Line := Trim(GetToken(Line,2,':')) + '=' + Name;

            if (LastDelimiter('[', Line) <> 0) then
            begin
               Delete(Line, LastDelimiter('[', Line), 1);
               Delete(Line, LastDelimiter(']', Line), 1);
            end;

            PinInfo.Add(Line);
         end;
      inc(i);
   end;

   // Now we need to do aditional fixes on pin info
   for i := 0 to PinInfo.Count - 1 do
   begin
      Line := PinInfo[i];

      if (Line[Length(Line)] = ')') and (Line[Length(Line) - 1] = 'n') and (Line[Length(Line) - 2] = '(') then
      begin
         Name := PinInfo.Names[i];
         Value := PinInfo.ValueFromIndex[i];

         SetLength(Value, Length(Value) - 3);

         PosValue := Value;

         Indeks := Length(Value);

         AsciiCode := ord(Value[Indeks]);

         // We need to check if we have number
         while (AsciiCode > 47) and (AsciiCode < 58) do
         begin
            Dec(Indeks);
            AsciiCode := ord(Value[Indeks]);
         end;

         if indeks = Length(Value) then
            Value := Value + '_N'
         else
            Insert('_N', Value, Indeks + 1);

         // We add new value to stringList
         Pininfo.Values[Name] := Value;

         // Now we need to find positive net


         For j := 0 to PinInfo.Count - 1 do
         begin
            if (PinInfo.ValueFromIndex[j] = PosValue) then
            begin
               if indeks = Length(PosValue) then
                  PosValue := PosValue + '_P'
               else
                  Insert('_P', PosValue, Indeks + 1);
               PinInfo.ValueFromIndex[j] := PosValue;
            end;
         end;
      end;
   end;
   // PinInfo.SaveToFile('C:\Users\Petar\Desktop\Report3.Txt');
end;

Procedure ImportFromLattice(extension : string);
var
   i, j     : Integer;
   Flag     : Integer;
   FileName : String;
   PinFile  : TstringList;
   Line     : String;

   PinName  : String;
   NetName  : String;

   NetText  : String;
   NetIndex : String;
begin

   SaveDialog.Title  := 'Import pin info from *.' + extension + ' file for Component ' + ComboBoxDesignator.Text;
   SaveDialog.Filter := AnsiUpperCase(extension) + ' file (*.' + extension + ')|*.' + extension;

   Flag := OpenDialog.Execute;
   if (not Flag) then exit;

   FileName := OpenDialog.FileName;

   // Load ucf file to PinFile
   PinFile := TStringList.Create;
   PinFile.LoadFromFile(Filename);

   i := 0;

   While i < PinFile.Count do
   begin
      Line := PinFile[i];
      Inc(i);
      if Line = 'Pinout by Pin Number:' then break;
   end;

   i := i + 3;
   while Line[1] <> '+' do
   begin
      Line := PinFile[i];

      // Delete first character - |
      if Line[1] = '|' then Delete(Line, 1, 1);

      PinName := GetToken(Line, 1, '|');
      NetName := GetToken(Line, 2, '|');

      PinName := Trim(PinName);
      NetName := Trim(NetName);

      // Delete bank info from pin name
      Delete(PinName, LastDelimiter('/', PinName), Length(PinName) - LastDelimiter('/', PinName) + 1);

      if (NetName = '') or (NetName = 'unused, PULL:UP') or (NetName = 'unused, PULL:DOWN') then
         NetName := 'DoNotConnectOnSCH';

      if NetName[Length(NetName)] = '+' then
      begin
         SetLength(NetName, Length(NetName) - 1);
    
         NetText  := GetNetText('=' + NetName);
         NetIndex := GetNetIndex('=' + NetName);

         NetName := NetText + '_P' + NetIndex;
      end;

      if NetName[Length(NetName)] = '-' then
      begin
         SetLength(NetName, Lenght(NetName) - 1);

         NetText  := GetNetText('=' + NetName);
         NetIndex := GetNetIndex('=' + NetName);

         NetName := NetText + '_N' + NetIndex;
      end;

      PinInfo.Add(PinName + '=' + NetName);

      Inc(i);
   end;
end;

Procedure ImportFromXilinx(extension : string);
var
   i, j     : Integer;
   Flag     : Integer;
   FileName : String;
   PinFile  : TstringList;
   Line     : String;

   Indeks   : Integer;
   Name     : String;
   Value    : String;

   AsciiCode : Integer;
   PosValue  : String;

   TempLine : String;

begin
   SaveDialog.Title  := 'Import pin info from *.' + extension + ' file for Component ' + ComboBoxDesignator.Text;
   SaveDialog.Filter := AnsiUpperCase(extension) + ' file (*.' + extension + ')|*.' + extension;

   Flag := OpenDialog.Execute;
   if (not Flag) then exit;

   FileName := OpenDialog.FileName;

   // Load ucf file to PinFile
   PinFile := TStringList.Create;
   PinFile.LoadFromFile(Filename);

   i := 0;

   While i < PinFile.Count do
   begin
      Line := PinFile[i];
      Line := Trim(Line);

      if (Length(Line) > 3) then
         if (AnsiUpperCase(Line[1]) = 'N') and (AnsiUpperCase(Line[2]) = 'E') and (AnsiUpperCase(Line[3]) = 'T') then
         Begin
            Line := StringReplace(Line, Chr(9), ' ', MkSet(rfReplaceAll));
            Line := RemoveMultipleSpaces(Line);
            Value := Trim(GetToken(Line,2,' '));

            // Check if we have " at the start or end
            if (Value[1] = '"') then
               Delete(Value,1,1);

            if (Value[Length(Value)] = '"') then
               SetLength(Value, Length(Value) - 1);

            // Remove brackets in busses
            if (LastDelimiter('(', Value) <> 0) then
            begin
               Delete(Value, LastDelimiter('(', Value), 1);
               Delete(Value, LastDelimiter(')', Value), 1);
            end;

            if (LastDelimiter('[', Value) <> 0) then
            begin
               Delete(Value, LastDelimiter('[', Value), 1);
               Delete(Value, LastDelimiter(']', Value), 1);
            end;

            Name := Trim(GetToken(Line,3,' '));

            if Length(Name) < 5 then
               Name := Trim(GetToken(Line,5,' '))
            else
               Delete(Name, 1, 4);

            // If there is trailing ';' - remove it
            if (Name[Length(Name)] = ';') then
               SetLength(Name, Length(Name) - 1);

            // Check if we have " at the start or end
            if (Name[1] = '"') then
               Delete(Name,1,1);

            if (Name[Length(Name)] = '"') then
               SetLength(Name, Length(Name) - 1);

            // Write all down
            PinInfo.Add(Name + '=' + Value);
         end;

      Inc(i);
   end;
end;

Procedure ImportFromCustom(extension : String);
var
   i, j     : Integer;
   Flag     : Integer;
   FileName : String;
   PinFile  : TstringList;
   Line     : String;

   PinName  : String;
   NetName  : String;

   AsciiCode : Integer;
   PosValue  : String;

   TempLine : String;

begin

   SaveDialog.Title  := 'Import pin info from *.' + extension + ' or *.csv file for Component ' + ComboBoxDesignator.Text;
   SaveDialog.Filter := AnsiUpperCase(extension) + ' file (*.' + extension + ')|*.' + extension + 'CSV file (*.csv)|*.csv';

   Flag := OpenDialog.Execute;
   if (not Flag) then exit;

   FileName := OpenDialog.FileName;

   // Load ucf file to PinFile
   PinFile := TStringList.Create;
   PinFile.LoadFromFile(Filename);

   for i := 0 to Pinfile.Count - 1 do
   begin
      Line := PinFile[i];  

      // delete delimiter characters at the beginning of the line
      While (Line[1] = '=') or (Line[1] = ',') or (Line[1] = ';') do
         Delete(Line,1,1);

      // delete delimiter characters at the end of the line
      j := LastDelimiter('=,;',Line);

      while (j = Length(Line)) do
      begin
         Delete(Line,Length(Line),1);
         j := LastDelimiter('=,;',Line);
      end;

      if (j <> 0) then
      begin
         PinName := Line;
         Netname := Line;

         Delete(PinName, j, Length(PinName) - j + 1);
         Delete(NetName, 1, j);

         PinName := Trim(PinName);
         NetName := Trim(NetName);

         if (PinName <> '') and (NetName <> '') then
            PinInfo.Add(PinName + '=' + NetName);
      end;
   end;
end;



// Here we have functions that generate files to export To Vendor Tools
Procedure ExportToActel(extension : string);
begin
   close;
end;

Procedure ExportToAltera(extension : string);
var
   Lista    : TStringList;
   Line     : String;
   PinName  : String;
   NetName  : String;
   i        : Integer;
   FileName : String;
   NetIndex : String;
   DiffPair : String;
   Indeks   : Integer;
begin
   Lista := TStringList.Create;
   // set_location_assignment -to "ADC_CAL" PIN_F29
   // PinInfo.SaveToFile('C:\Report.Txt');

   for i := 0 to PinInfo.Count - 1 do
   begin
      Line := PinInfo[i];

      PinName  := GetPinName(Line);
      NetName  := GetNetText(Line);
      Netindex := GetNetIndex(Line);
      DiffPair := IsDiffPair(Line);

      // Here we need to check the pin name - if it is diffpair, or a bus

      Indeks  := Length(NetName);

      Line := 'set_location_assignment -to "' + NetName;

      if NetIndex <> '' then Line := Line + '\[' + NetIndex + '\]';

      Line := Line + '" PIN_' + PinName;

      // Since there is no need for negative net names
      if DiffPair <> 'Negative' then
         Lista.Add(Line);
   end;

   SaveDialog.Title  := 'Export pin info to *.' + extension + ' file for Component ' + ComboBoxDesignator.Text;
   SaveDialog.Filter := AnsiUpperCase(extension) + ' file (*.' + extension + ')|*.' + extension;

   i := SaveDialog.Execute;
   if (not i) then exit;

   FileName := SaveDialog.FileName;
   FileName := ChangeFileExt(FileName, '.' + extension);

   Lista.SaveToFile(FileName);

   close;
end;

Procedure ExportToLattice(extension : string);
var
   Lista    : TStringList;
   Line     : String;
   PinName  : String;
   NetName  : String;
   NetIndex : String;
   DiffPair : String;
   i        : Integer;
   FileName : String;
begin
   Lista := TStringList.Create;

   for i := 0 to PinInfo.Count - 1 do
   begin
      Line := PinInfo[i];

      PinName  := GetPinName(Line);
      NetName  := GetNetText(Line);
      NetIndex := GetNetIndex(Line);
      DiffPair := IsDiffPair(Line);

      if NetIndex <> '' then
         NetName := NetName + NetIndex;

      if DiffPair <> 'Negative' then
      begin
         Line := 'LOCATE COMP "' + NetName + '" SITE "' + PinName + '" ;';
         Lista.Add(Line);
      end;

      if DiffPair = 'Positive' then
         Lista.Add('IOBUF PORT "' + NetName + '" IO_TYPE=LVPECL33 ;');
   end;

   SaveDialog.Title  := 'Export pin info to *.' + extension + ' file for Component ' + ComboBoxDesignator.Text;
   SaveDialog.Filter := AnsiUpperCase(extension) + ' file (*.' + extension + ')|*.' + extension;

   i := SaveDialog.Execute;
   if (not i) then exit;

   FileName := SaveDialog.FileName;
   FileName := ChangeFileExt(FileName, '.' + extension);

   Lista.SaveToFile(FileName);

   close;
end;

Procedure ExportToXilinx(extension : string);
var
   Lista    : TStringList;
   Line     : String;
   PinName  : String;
   NetName  : String;
   NetIndex : String;
   DiffPair : String;
   i        : Integer;
   FileName : String;
begin
   Lista := TStringList.Create;

   for i := 0 to PinInfo.Count - 1 do
   begin
      Line := PinInfo[i];

      PinName  := GetPinName(Line);
      NetName  := GetNetText(Line);
      NetIndex := GetNetIndex(Line);
      DiffPair := IsDiffPair(Line);

      if DiffPair = 'Positive' then
         NetName := NetName + '_P';

      if DiffPair = 'Negative' then
         NetName := NetName + '_N';

      if NetIndex <> '' then
         NetName := NetName + '<' + NetIndex + '>';

      Line := 'NET "' + NetName + '"      LOC = "' + PinName + '";';
      Lista.Add(Line);
   end;

   SaveDialog.Title  := 'Export pin info to *.' + extension + ' file for Component ' + ComboBoxDesignator.Text;
   SaveDialog.Filter := AnsiUpperCase(extension) + ' file (*.' + extension + ')|*.' + extension;

   i := SaveDialog.Execute;
   if (not i) then exit;

   FileName := SaveDialog.FileName;
   FileName := ChangeFileExt(FileName, '.' + extension);

   Lista.SaveToFile(FileName);

   close;
end;

Procedure ExportToCsv(extension : string);
var
   Lista    : TStringList;
   PinName  : String;
   NetName  : String;
   i        : Integer;
   FileName : String;
begin
   Lista := TStringList.Create;

   for i := 0 to PinInfo.Count - 1 do
   begin
      PinName := PinInfo.Names[i];
      NetName := PinInfo.ValueFromIndex[i];

      Lista.Add(PinName + ',' + NetName);
   end;

   SaveDialog.Title  := 'Export pin info to *.' + extension + ' file for Component ' + ComboBoxDesignator.Text;
   SaveDialog.Filter := AnsiUpperCase(extension) + ' file (*.' + extension + ')|*.' + extension;

   i := SaveDialog.Execute;
   if (not i) then exit;

   FileName := SaveDialog.FileName;
   FileName := ChangeFileExt(FileName, '.'+ extension);

   Lista.SaveToFile(FileName);

   close;
end;



procedure TVendorToolsForm.ButtonCancelClick(Sender: TObject);
begin
   Close;
end;



procedure TVendorToolsForm.ButtonOKClick(Sender: TObject);
var
   i, j       : Integer;
   Component  : IComponent;
   Part       : IPart;

   Iterator   : ISCH_Iterator;
   CompItr    : ISCH_Iterator;
   Comp       : ISCH_Component;
   Pin        : ISCH_Pin;

   NetItr     : ISCH_Iterator;

   NetLabel   : ISCH_NetLabel;
   Templabel  : ISCH_NetLabel;

   Wire       : ISCH_Wire;
   Tempwire   : ISCH_Wire;
   X1, Y1     : Integer;
   X2, Y2     : Integer;

   WireSize   : Integer;
   GridSize   : Integer;

   NoErc      : ISch_NoERC;
   TempNoERC  : ISch_NoERC;

   DiffPairDirective : ISCH_ParameterSet;
   TempDirective     : ISCH_ParameterSet;
   DiffPairParameter : ISCH_Parameter;

begin

   if ComboBoxDesignator.Text = '' then
   begin
      ShowMessage('Choose Component');
      exit;
   end;

   Component := nil;

   For i := 0 to FlatHierarchy.DM_ComponentCount - 1 do
      if AnsiCompareText(FlatHierarchy.DM_Components(i).DM_PhysicalDesignator, ComboBoxDesignator.Text) = 0 then
      begin
         Component := FlatHierarchy.DM_Components(i);
         break;
      end;

   if Component = nil then
   begin
      ShowMessage('Component "' + ComboBoxDesignator.Text + '" not found');
      exit;
   end;

   // We create PinInfo StringList
   PinInfo := TSTringList.Create;

   if RadioButtonImport.Checked then
   begin
      // Here we are importing info to PinInfo StringList
      if      RadioButtonActel.Checked   then ImportFromActel('')
      else if RadioButtonAltera.Checked  then ImportFromAltera('pin')
      else if RadioButtonLattice.Checked then ImportFromLattice('pad')
      else if RadioButtonXilinx.Checked  then ImportFromXilinx('ucf')
      else if RadioButtonCustom.Checked  then ImportFromCustom('txt');

      if PinInfo.Count = 0 then exit;

      // Now we have set up the PinInfo StringList.
      // We need to modify Altium Sch Documents

      for i := 0 to Component.DM_SubPartCount - 1 do
      begin
         Part := Component.DM_SubParts(i);

         // We need to find sch document this part is on
         SchDoc   := SCHServer.GetSchDocumentByPath(Part.DM_OwnerDocumentFullPath);
         GridSize := MilsToCoord(SchDoc.VisibleGridSize / cInternalPrecision);

         // WireSize := StrToInt(EditLength.Text) * GridSize;
         // Old wire size

         // Now wire size will always be 5 * grid size
         WireSize := 5 * GridSize;

         SchServer.ProcessControl.PreProcess(SchDoc, '');

         If SchDoc = nil then
         begin
            ShowMessage('Can not get document: ' + Part.DM_OwnerDocumentFullPath);
            exit;
         end;

         // Cacle through all parts on this document, find the subpart
         Iterator := SchDoc.SchIterator_Create;
         Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));

         Try
            Comp := Iterator.FirstSchObject;

           // ShowMessage(Part.DM_OwnerDocumentFullPath + '   ' + Comp.OwnerDocument.DocumentName);

            While Comp <> Nil Do
            Begin
                if (Comp.Designator.Text = Part.DM_LogicalDesignator) and (Part.DM_PartID = Comp.CurrentPartID) and (Comp.OwnerDocument.DocumentName = SchDoc.DocumentName) then
                   begin

                   SchServer.ProcessControl.PreProcess(SchDoc, '');

                   Try
                       // We have found the sub-part - now cycle through all pins in it and make iterator that will catch all
                       // Net Labels this pins connect to
                       CompItr := Comp.SchIterator_Create;
                       CompItr.AddFilter_ObjectSet(MkSet(ePin));

                       Pin := CompItr.FirstSchObject;
                       While Pin <> Nil Do
                       Begin

                          if Pin.OwnerPartId = Comp.CurrentPartID then
                          begin


                                // We need another iterator that will find
                                // 1 - Wire
                                // 2 - NetLabel
                                // 3 - NoERC Directive
                                // 4 - DiffPair directive

                              // Set vertexes
                             if Pin.Orientation = eRotate0 then
                             begin
                                X1 := Pin.Location.X + Pin.PinLength;
                                Y1 := Pin.Location.Y;
                                X2 := Pin.Location.X + Pin.PinLength + Wiresize;
                                Y2 := Pin.Location.Y;
                             end
                             else if Pin.Orientation = eRotate90 then
                             begin
                                X1 := Pin.Location.X;
                                Y1 := Pin.Location.Y + Pin.PinLength;
                                X2 := Pin.Location.X;
                                Y2 := Pin.Location.Y + Pin.PinLength + Wiresize;
                             end
                             else if Pin.Orientation = eRotate180 then
                             begin
                                X1 := Pin.Location.X - Pin.PinLength - Wiresize;
                                Y1 := Pin.Location.Y;
                                X2 := Pin.Location.X - Pin.PinLength;
                                Y2 := Pin.Location.Y;
                             end
                             else if Pin.Orientation = eRotate270 then
                             begin
                                X1 := Pin.Location.X;
                                Y1 := Pin.Location.Y - Pin.PinLength - Wiresize;
                                X2 := Pin.Location.X;
                                Y2 := Pin.Location.Y - Pin.PinLength;
                             end;

                             // First the wire
                             try
                                NetItr := SchDoc.SchIterator_Create;
                                NetItr.AddFilter_ObjectSet(MkSet(eWire));
                                NetItr.AddFilter_Area(X1 - 1, Y1 - 1, X2 + 1, Y2 + 1);

                                Wire := NetItr.FirstSchObject;
                                While (Wire <> nil) do
                                begin
                                   TempWire := Wire;
                                   Wire := NetItr.NextSchObject;

                                   SchDoc.RemoveSchObject(TempWire);

                                   SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress,c_BroadCast,
                                             SCHM_PrimitiveRegistration,TempWire.I_ObjectAddress);
                                end;
                             finally
                                SchDoc.SchIterator_Destroy(NetItr);
                             end;


                             Wire := SchServer.SchObjectFactory(eWire, eCreate_Default);

                             Wire.Location := Point(X1, Y1);
                             Wire.InsertVertex := 1;
                             Wire.SetState_Vertex(1, Point(X1, Y1));

                             Wire.InsertVertex := 2;
                             Wire.SetState_Vertex(2, Point(X2, Y2));

                             SchDoc.RegisterSchObjectInContainer(Wire);

                             SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress,c_BroadCast,
                                       SCHM_PrimitiveRegistration,Wire.I_ObjectAddress);


                             // now the net label - delete old one
                             try

                                NetItr := SchDoc.SchIterator_Create;
                                NetItr.AddFilter_ObjectSet(MkSet(eNetLabel));
                                NetItr.AddFilter_Area(X1 - 1, Y1 - 1, X2 + 1, Y2 + 1);

                                NetLabel := NetItr.FirstSchObject;

                                while NetLabel <> nil do
                                begin

                                   Templabel := nil;

                                   if (Pin.Orientation = eRotate0) or (Pin.Orientation = eRotate180) then
                                   begin
                                      if (NetLabel.Location.Y = Y1) and (NetLabel.Location.X >= X1) and (NetLabel.Location.X <= X2) then
                                         TempLabel := NetLabel;
                                   end
                                   else
                                   begin
                                      if (NetLabel.Location.X = X1) and (NetLabel.Location.Y >= Y1) and (NetLabel.Location.Y <= Y2) then
                                         TempLabel := NetLabel;
                                   end;
                                   NetLabel := NetItr.NextSchObject;

                                   if TempLabel <> nil then
                                   begin
                                      SchDoc.RemoveSchObject(TempLabel);

                                      SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress,c_BroadCast,
                                                SCHM_PrimitiveRegistration,TempLabel.I_ObjectAddress);
                                   end;
                                end;
                             finally
                                SchDoc.SchIterator_Destroy(NetItr);
                             end;

                             // Now the NoERC directive - delete all
                             try

                                NetItr := SchDoc.SchIterator_Create;
                                NetItr.AddFilter_ObjectSet(MkSet(eNoERC));
                                NetItr.AddFilter_Area(X1 - 1, Y1 - 1, X2 + 1, Y2 + 1);

                                NoERC := NetItr.FirstSchObject;
                                while NoERC <> nil do
                                begin
                                   TempNoERC := NoERC;
                                   NoERC := NetItr.NextSchObject;

                                   SchDoc.RemoveSchObject(TempNoERC);

                                   SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress,c_BroadCast,
                                             SCHM_PrimitiveRegistration,TempNoERC.I_ObjectAddress);
                                end;
                             finally
                                SchDoc.SchIterator_Destroy(NetItr);
                             end;

                             // Now the Diff Pair directives - delete all
                             try

                                NetItr := SchDoc.SchIterator_Create;
                                NetItr.AddFilter_ObjectSet(MkSet(eParameterSet));
                                NetItr.AddFilter_Area(X1 - 1, Y1 - 1, X2 + 1, Y2 + 1);

                                DiffPairDirective := NetItr.FirstSchObject;
                                while DiffPairDirective <> nil do
                                begin
                                   TempDirective := nil;

                                   if (Pin.Orientation = eRotate0) or (Pin.Orientation = eRotate180) then
                                   begin
                                      if (DiffPairDirective.Location.Y = Y1) and (DiffPairDirective.Location.X >= X1) and (DiffPairDirective.Location.X <= X2) then
                                         TempDirective := DiffPairDirective;
                                   end
                                   else
                                   begin
                                      if (DiffPairDirective.Location.X = X1) and (DiffPairDirective.Location.Y >= Y1) and (DiffPairDirective.Location.Y <= Y2) then
                                         TempDirective := DiffPairDirective;
                                   end;

                                   DiffPairDirective := NetItr.NextSchObject;

                                   if TempDirective <> nil then
                                   begin
                                      SchDoc.RemoveSchObject(TempDirective);

                                      SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress,c_BroadCast,
                                                SCHM_PrimitiveRegistration,TempDirective.I_ObjectAddress);
                                   end;

                                end;
                             finally
                                SchDoc.SchIterator_Destroy(NetItr);
                             end;


                             // modify net info based on gotten objects
                             if (Pininfo.Values[Pin.Designator] = 'DoNotConnectOnSCH') or (Pininfo.Values[Pin.Designator] = '') then
                             begin
                                // in This case we have no connection - place NoERC
                                NoERC := SchServer.SchObjectFactory(eNoERC, eCreate_Default);

                                if      Pin.Orientation = eRotate0 then
                                   NoERC.Location    := Point(X2 -  2 *GridSize, Y2)
                                else if Pin.Orientation = eRotate90 then
                                   NoERC.Location    := Point(X2, Y2 - 2 * GridSize)
                                else if Pin.Orientation = eRotate180 then
                                   NoERC.Location    := Point(X1 + 2 * GridSize, Y1)
                                else if Pin.Orientation = eRotate270 then
                                   NoERC.Location    := Point(X1, Y1 + 2 * GridSize);

                                SchDoc.AddSchObject(NoERC);

                                SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress,c_BroadCast,
                                       SCHM_PrimitiveRegistration,NoERC.I_ObjectAddress);
                             end
                             else
                             begin
                                NetLabel := SchServer.SchObjectFactory(eNetLabel, eCreate_Default);

                                //SchServer.RobotManager.SendMessage(NetLabel.I_ObjectAddress, c_BroadCast, SCHM_BeginModify, c_NoEventData);

                                NetLabel.Text := PinInfo.Values[Pin.Designator];


                                if (Pin.Orientation = eRotate0) then
                                begin
                                   NetLabel.Location := Point(X1 + 3 * GridSize, Y1);
                                   NetLabel.Orientation := eRotate0;
                                end
                                else if (Pin.Orientation = eRotate90) then
                                begin
                                   NetLabel.MoveToXY(X1, Y1 + 3 * GridSize);
                                   NetLabel.RotateBy90(Point(X1, Y1 + 3 * GridSize), eRotate90);
                                end
                                else if (Pin.Orientation = eRotate180) then
                                begin
                                   NetLabel.Location := Point(X1 + 2 * GridSize, Y1);
                                   NetLabel.Orientation := eRotate0;
                                   NetLabel.justification := akRight;
                                end
                                else if (Pin.Orientation = eRotate270) then
                                begin
                                   NetLabel.MoveToXY(X1, Y1 + 2 * GridSize);
                                   NetLabel.RotateBy90(Point(X1, Y1 + 2 * GridSize), eRotate90);
                                   NetLabel.justification := akRight;
                                end;


                                //SchServer.RobotManager.SendMessage(NetLabel.I_ObjectAddress, c_BroadCast, SCHM_EndModify, c_NoEventData);

                                SchDoc.RegisterSchObjectInContainer(NetLabel);
                                SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress,c_BroadCast,
                                       SCHM_PrimitiveRegistration,NetLabel.I_ObjectAddress);

                                NetLabel.GraphicallyInvalidate;

                                // Now after net label is placed, we need to check weather Net Label is
                                // in diff pair. If it is, we need to gove it diff pair directive.

                                if (IsDiffPair(NetLabel.Text) <> 'None') then
                                begin
                                   // Now we need to add diff pair directive here
                                   DiffPairParameter := SchServer.SchObjectFactory(eParameter, eCreate_Default);
                                   DiffPairParameter.Name := 'DifferentialPair';
                                   DiffPairParameter.Text := 'True';
                                   DiffPairParameter.IsHidden := True;

                                   DiffPairDirective := SchServer.SchObjectFactory(eParameterSet, eCreate_Default);
                                   DiffPairDirective.AddSchObject(DiffPairParameter);

                                   if ((Pin.Orientation = eRotate0) or (Pin.Orientation = eRotate90)) then
                                   begin
                                      DiffPairDirective.Location    := Point(X1, Y1);
                                      DiffPairDirective.Orientation := NetLabel.Orientation;
                                   end
                                   else
                                   begin
                                      DiffPairDirective.Location    := Point(NetLabel.Location.X, NetLabel.Location.Y);
                                      DiffPairDirective.Orientation := NetLabel.Orientation;
                                   end;

                                   SchDoc.AddSchObject(DiffPairDirective);

                                   SchServer.RobotManager.SendMessage(SchDoc.I_ObjectAddress,c_BroadCast,
                                          SCHM_PrimitiveRegistration,DiffPairDirective.I_ObjectAddress);
                                end;

                             end;
                          end;

                          Pin := CompItr.NextSchObject;
                       End;
                   Finally
                       Comp.SchIterator_Destroy(CompItr);
                   End;

                   SchServer.ProcessControl.PostProcess(SchDoc, '');

                   SchDoc.GraphicallyInvalidate;


                end;

                Comp := Iterator.NextSchObject;
            End;
         Finally
            SchDoc.SchIterator_Destroy(Iterator);
         End;

         SchServer.ProcessControl.PostProcess(SchDoc, '');
      end;
   end
   else if RadioButtonExport.Checked then
   begin
      // Here we export info
      // First We need to set up the PinInfo StringList.

      for i := 0 to Component.DM_SubPartCount - 1 do
      begin
         Part := Component.DM_SubParts(i);

         // We need to find sch document this part is on
         SchDoc := SCHServer.GetSchDocumentByPath(Part.DM_OwnerDocumentFullPath);   

         If SchDoc = nil then
         begin
            ShowMessage('Can not get document: ' + Part.DM_OwnerDocumentFullPath);
            exit;
         end;

         // Cacle through all parts on this document, find the subpart
         Iterator := SchDoc.SchIterator_Create;
         Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));

         Try
            Comp := Iterator.FirstSchObject;

           // ShowMessage(Part.DM_OwnerDocumentFullPath + '   ' + Comp.OwnerDocument.DocumentName);

            While Comp <> Nil Do
            Begin
                if (Comp.Designator.Text = Part.DM_LogicalDesignator) and (Part.DM_PartID = Comp.CurrentPartID) and (Comp.OwnerDocument.DocumentName = SchDoc.DocumentName) then
                   begin
                   Try       
                       // We have found the sub-part - now cycle through all pins in it and make iterator that will catch all
                       // Net Labels this pins connect to
                       CompItr := Comp.SchIterator_Create;
                       CompItr.AddFilter_ObjectSet(MkSet(ePin));

                       Pin := CompItr.FirstSchObject;
                       While Pin <> Nil Do
                       Begin
                          // We need another iterator that will find

                          if (Pin.OwnerPartId = Comp.CurrentPartID) and (Pin.OwnerPartDisplayMode = Comp.Displaymode) then
                          begin

                             try
                                NetItr := SchDoc.SchIterator_Create;
                                NetItr.AddFilter_ObjectSet(MkSet(eNetLabel));

                                if      Pin.Orientation = eRotate0 then
                                   NetItr.AddFilter_Area(Pin.Location.X - 1, Pin.Location.Y - 1, Pin.Location.X + 10000000, Pin.Location.Y + 1)
                                else if Pin.Orientation = eRotate90 then
                                   NetItr.AddFilter_Area(Pin.Location.X - 1, Pin.Location.Y - 1, Pin.Location.X + 1, Pin.Location.Y + 10000000)
                                else if Pin.Orientation = eRotate180 then
                                   NetItr.AddFilter_Area(Pin.Location.X - 10000000, Pin.Location.Y - 1, Pin.Location.X + 1, Pin.Location.Y + 1)
                                else if Pin.Orientation = eRotate270 then
                                   NetItr.AddFilter_Area(Pin.Location.X - 1, Pin.Location.Y - 10000000, Pin.Location.X + 1, Pin.Location.Y + 1);

                                NetLabel := NetItr.FirstSchObject;
                                Templabel := nil;

                                while NetLabel <> nil do
                                begin
                                   if (Pin.Orientation = eRotate0) or (Pin.Orientation = eRotate180) then
                                   begin
                                      if Pin.Location.Y = NetLabel.Location.Y then
                                      begin
                                         if Templabel = nil then
                                            TempLabel := NetLabel
                                         else if abs(Pin.Location.X - NetLabel.Location.X) < abs(Pin.Location.X - TempLabel.Location.X) then
                                            TempLabel := NetLabel;
                                      end;
                                   end
                                   else
                                   begin
                                      if Pin.Location.X = NetLabel.Location.X then
                                      begin
                                         if Templabel = nil then
                                            TempLabel := NetLabel
                                         else if abs(Pin.Location.Y - NetLabel.Location.Y) < abs(Pin.Location.Y - TempLabel.Location.Y) then
                                            TempLabel := NetLabel;
                                      end;
                                   end;

                                   NetLabel := NetItr.NextSchObject;
                                end;
                             finally
                                SchDoc.SchIterator_Destroy(NetItr);
                             end;

                             // This is the case we have netlabel (in TempLabel) and pin (in pin)
                             // We will write them in PinInfo
                             if TempLabel <> nil then
                                PinInfo.Add(Pin.Designator + '=' + TempLabel.Text);
                          end;

                          Pin := CompItr.NextSchObject;
                       End;
                   Finally
                       Comp.SchIterator_Destroy(CompItr);
                   End;
                end;

                Comp := Iterator.NextSchObject;
            End;
         Finally
            SchDoc.SchIterator_Destroy(Iterator);
         End;

         SchDoc := nil;
      end;

      // Now that we have set up PinInfo StringList, we need to generate the file
      if      RadioButtonActel.Checked   then ExportToActel('')
      else if RadioButtonAltera.Checked  then ExportToAltera('tcl')
      else if RadioButtonLattice.Checked then ExportToLattice('lpf')
      else if RadioButtonXilinx.Checked  then ExportToXilinx('ucf')
      else if RadioButtonCustom.Checked  then ExportToCsv('csv');
   end;
   close;
end;



procedure Start;
var
   PcbProject    : IProject;
   ComponentNum  : Integer;
begin
   PcbProject := GetWorkspace.DM_FocusedProject;
   if PcbProject = nil then exit;

   If (PcbProject = nil) then
   Begin
      ShowMessage('Current Project is not a PCB Project');
      exit;
   end;

   If (AnsiUpperCase(ExtractFileExt(PCBProject.DM_ProjectFileName)) <> '.PRJPCB') then
   Begin
      ShowMessage('Current Project is not a PCB Project');
      exit;
   end;

   // Compile project

   // First try compiling the project
   PcbProject.DM_Compile;

   // Try to open the flattened document
   FlatHierarchy := PCBProject.DM_DocumentFlattened;
   if (FlatHierarchy = nil) then
   begin
       ShowMessage('NOTICE: Compile the Project before Running this script.');
       Exit;
   end;

   For ComponentNum := 0 to FlatHierarchy.DM_ComponentCount - 1 do
      ComboBoxDesignator.Items.Add(FlatHierarchy.DM_Components(ComponentNum).DM_PhysicalDesignator);

   VendorToolsForm.ShowModal;
end;
