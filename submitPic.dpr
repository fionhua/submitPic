program submitPic;

uses
  Forms,
  SysUtils,
  Windows,
  Classes,
  Messages,
  superobject {Json解析插件},
  TConfiguratorUnit,
  TLoggerUnit {记录日志文件};

type TUpdateFileInfo = record
  FileList:array of string;
  Dir:string;
  end;

var AppPath:String;
{$R *.res}

//功能概述：
//1.通过Python分析Json，再打开对应的网页，并填写信息
//2.当python上传图片，需要：
//  2.1保存需要上传的文件列表到[picList.json]
//  2.2调用本程序，将[picList.json]指定的图片地址全部上传

//在减少占用资源的情况下，等待MSecs毫秒
procedure WaitSomeTime(MSecs:LongInt);
var FirstTickCount,Now:LongInt;
begin
  FirstTickCount := GetTickCount();
  repeat
  Application.ProcessMessages;
  Now := GetTickCount();
  until (Now - FirstTickCount >= MSecs) or (Now < FirstTickCount);
end;

//解析当前目录下的[picList.json]文件
function GetUpLoadFile():TUpdateFileInfo;
var aJson: ISuperObject;
    JsonStrings:TStringList;
    delFlag:Boolean;
    i:Integer;
begin
  if not FileExists(AppPath + 'picList.json') then
    begin
    TLogger.GetInstance.Error(FormatDateTime('YYYY-MM-DD hh:nn:ss',now) + '当前应用程序目录下，找不到[picList.json]文件,程序退出。');
    Exit;
    end;

  JsonStrings:=TStringList.Create;
  JsonStrings.LoadFromFile(AppPath + 'picList.json');
  JsonStrings.Text := Utf8ToAnsi(JsonStrings.Text);
  aJson:=SO(JsonStrings.Text);

  //如果picList.json文件中没有找到FileLists字段，则退出
  if aJson['FileLists']=nil then
    begin
    TLogger.GetInstance.Error(FormatDateTime('YYYY-MM-DD hh:nn:ss',now) + '待上传图片文件列表[FileLists]没有找到,程序退出。');
    Exit;
    end;
  if aJson['Dir']=nil then
    begin
    TLogger.GetInstance.Error(FormatDateTime('YYYY-MM-DD hh:nn:ss',now) + '待上传图片文件目录[Dir]没有找到,程序退出。');
    Exit;
    end;

  Result.Dir := aJson['Dir'].AsString;
  SetLength(Result.FileList, aJson['FileLists'].AsArray.Length);
  for i:=0 to aJson['FileLists'].AsArray.Length-1 do
    Result.FileList[i] := aJson['FileLists'].AsArray[i].AsString;

  aJson.Clear();
  JsonStrings.Free;

  //获取了上传文件信息后，删除picList.json文件
  for i:=0 to 30 do
    begin
    delFlag := DeleteFile(PAnsiChar(AppPath + 'picList.json'));
    if not delFlag then WaitSomeTime(500) else Break;
    end;
  if not delFlag then TLogger.GetInstance.Error(FormatDateTime('YYYY-MM-DD hh:nn:ss',now) + '文件[picList.json]删除失败。');
end;

function GetCurDialogPath(pathEdtHandle:HWND):string;//传入参数为“打开文件对话框”窗口中，顶部包含路径的ToolbarWindow32之句柄，返回值为该ToolbarWindow32包含的当前路径
var curPath_arr: array[0..254] of Char;
    i:Integer;
begin
  GetWindowText(pathEdtHandle, @curPath_arr, SizeOf(curPath_arr));
  result := curPath_arr;
  i := Pos('地址:',result);
  if i>0 then Delete(result, i,5);
  result := Trim(result);
end;

//上传picList.json中的图片文件
procedure UpdatePicture;
var openDialog:HWND;//通过句柄'#32770'，可以找到打开文件对话框
    pathEdtHandle:HWND;//代表打开文件对话框顶部的Edit，可以从中获取对话框当前路径
    edtHandle:HWND;//对话框下方，用于填写打开文件名的Edit框，如果在里面填写路径，点击打开按钮，会切换对话框当前路径
    btnHandle:HWND;//代表打开按钮

    UpdateFileInfo:TUpdateFileInfo;//用于保存需要上传的文件目录、及文件列表
    curPath:string;//用于保存当前打开对话框选定的地址
    sameFlag:Boolean;
    temp:string;
    i:Integer;
begin
  //使用spy++工具 从父窗口层层获取到"打开文件”对话框句柄
  try
  openDialog := FindWindow('#32770','打开');{找到浏览器弹出的“打开”文件对话框}
  if openDialog=0 then raise Exception.CreateFmt('%s:%s', [FormatDateTime('YYYY-MM-DD hh:nn:ss',now),'打开文件对话框句柄没有找到。']);


  //找到显示对话框当前路径的Edit框
  pathEdtHandle := FindWindowEx(openDialog,0,'WorkerW',nil);
  pathEdtHandle := FindWindowEx(pathEdtHandle,0,'ReBarWindow32',nil);
  pathEdtHandle := FindWindowEx(pathEdtHandle,0,'Address Band Root',nil);
  pathEdtHandle := FindWindowEx(pathEdtHandle,0,'msctls_progress32',nil);
  pathEdtHandle := FindWindowEx(pathEdtHandle,0,'Breadcrumb Parent',nil);
  pathEdtHandle := FindWindowEx(pathEdtHandle,0,'ToolbarWindow32',nil);
  if pathEdtHandle=0 then raise Exception.CreateFmt('%s:%s', [FormatDateTime('YYYY-MM-DD hh:nn:ss',now),'打开文件对话框de当前路径句柄没有找到。']);


  //获得对话框下方，可填写文件名的Edit框（切换路径也是使用这里）
  edtHandle:= FindWindowEx(openDialog,0,'ComboBoxEx32',nil);
  edtHandle:= FindWindowEx(edtHandle,0,'ComboBox',nil);
  edtHandle:= FindWindowEx(edtHandle,0,'Edit',nil);
  if edtHandle=0 then raise Exception.CreateFmt('%s:%s', [FormatDateTime('YYYY-MM-DD hh:nn:ss',now),'打开文件对话框de填写路径句柄没有找到。']);

  //获得对话框下方的“确定”按钮
  btnHandle := FindWindowEx(openDialog,0,'Button',nil);
  if btnHandle=0 then raise Exception.CreateFmt('%s:%s', [FormatDateTime('YYYY-MM-DD hh:nn:ss',now),'打开文件对话框de确定按钮句柄没有找到。']);

  //从Json文件中，获取要上传的文件列表、文件所在目录
  UpdateFileInfo := GetUpLoadFile();
  //统一在最后取消"\、/"以便于比较
  while IsPathDelimiter(UpdateFileInfo.Dir,Length(UpdateFileInfo.Dir)) do
    UpdateFileInfo.Dir := Copy(UpdateFileInfo.Dir,1,Length(UpdateFileInfo.Dir)-1);

  //获得对话框当前所在目录
  curPath := GetCurDialogPath(pathEdtHandle);
  for i:=0 to 30 do
    begin
    //去掉当前目录的最后"\/"标志，以便于比较
    while IsPathDelimiter(curPath,Length(curPath)) do
      curPath := Copy(curPath,1,Length(curPath)-1);

    //切换打开文件对话框当前目录到上传文件列表的目录
    if curPath<>UpdateFileInfo.Dir then
      begin
      //发送上传文件所在的目录到Edit框
      SendMessage(edtHandle,WM_SETTEXT,255,Integer(PChar(UpdateFileInfo.Dir)));
      SendMessage(btnHandle,WM_LBUTTONDOWN,0,0); //发送”按下“消息
      SendMessage(btnHandle,WM_LBUTTONUP,0,0);   //发送”放开“消息
      //等待500毫秒，再进入下一次判断，检查对话框当前目录是否已经切换到需要上传文件的所在目录
      WaitSomeTime(500);
      end;
    //再次刷新对话框当前所在目录
    curPath := GetCurDialogPath(pathEdtHandle);
    sameFlag := (curPath=UpdateFileInfo.Dir);
    if sameFlag then break;
    end;
    if not sameFlag then raise Exception.CreateFmt('%s:%s,指定目录为：%s', [FormatDateTime('YYYY-MM-DD hh:nn:ss',now),'点击确定按钮,无法切换到指定的目录。',UpdateFileInfo.Dir]);

  //此时，对话框当前目录已经切换到上传文件目录，开始想下方的文本框发送文件名列表，文件名需要双引号，并以空格为间隔
  temp := '';
  for i:=0 to Length(UpdateFileInfo.FileList)-1 do
    temp := temp + Format('"%s" ',[UpdateFileInfo.FileList[i]]);
  Delete(temp,Length(temp),1);
  SendMessage(edtHandle,WM_SETTEXT,255,Integer(PChar(temp)));
  //点击确定按钮
  SendMessage(btnHandle,WM_LBUTTONDOWN,0,0); //发送”按下“消息
  SendMessage(btnHandle,WM_LBUTTONUP,0,0);   //发送”放开“消息
  TLogger.GetInstance.Info(FormatDateTime('YYYY-MM-DD hh:nn:ss',now)+'上传图片文件成功。');
  except on e: Exception do
    TLogger.GetInstance.Error(e.message);
  end;

end;


begin
  Application.Initialize;
  AppPath := ExtractFilePath(Application.ExeName);
  doPropertiesConfiguration('log4delphi.properties'); //初始化日志控件
  UpdatePicture();
  //Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
