program submitPic;

uses
  Forms,
  SysUtils,
  Windows,
  Classes,
  Messages,
  superobject {Json�������},
  TConfiguratorUnit,
  TLoggerUnit {��¼��־�ļ�};

type TUpdateFileInfo = record
  FileList:array of string;
  Dir:string;
  end;

var AppPath:String;
{$R *.res}

//���ܸ�����
//1.ͨ��Python����Json���ٴ򿪶�Ӧ����ҳ������д��Ϣ
//2.��python�ϴ�ͼƬ����Ҫ��
//  2.1������Ҫ�ϴ����ļ��б�[picList.json]
//  2.2���ñ����򣬽�[picList.json]ָ����ͼƬ��ַȫ���ϴ�

//�ڼ���ռ����Դ������£��ȴ�MSecs����
procedure WaitSomeTime(MSecs:LongInt);
var FirstTickCount,Now:LongInt;
begin
  FirstTickCount := GetTickCount();
  repeat
  Application.ProcessMessages;
  Now := GetTickCount();
  until (Now - FirstTickCount >= MSecs) or (Now < FirstTickCount);
end;

//������ǰĿ¼�µ�[picList.json]�ļ�
function GetUpLoadFile():TUpdateFileInfo;
var aJson: ISuperObject;
    JsonStrings:TStringList;
    delFlag:Boolean;
    i:Integer;
begin
  if not FileExists(AppPath + 'picList.json') then
    begin
    TLogger.GetInstance.Error(FormatDateTime('YYYY-MM-DD hh:nn:ss',now) + '��ǰӦ�ó���Ŀ¼�£��Ҳ���[picList.json]�ļ�,�����˳���');
    Exit;
    end;

  JsonStrings:=TStringList.Create;
  JsonStrings.LoadFromFile(AppPath + 'picList.json');
  JsonStrings.Text := Utf8ToAnsi(JsonStrings.Text);
  aJson:=SO(JsonStrings.Text);

  //���picList.json�ļ���û���ҵ�FileLists�ֶΣ����˳�
  if aJson['FileLists']=nil then
    begin
    TLogger.GetInstance.Error(FormatDateTime('YYYY-MM-DD hh:nn:ss',now) + '���ϴ�ͼƬ�ļ��б�[FileLists]û���ҵ�,�����˳���');
    Exit;
    end;
  if aJson['Dir']=nil then
    begin
    TLogger.GetInstance.Error(FormatDateTime('YYYY-MM-DD hh:nn:ss',now) + '���ϴ�ͼƬ�ļ�Ŀ¼[Dir]û���ҵ�,�����˳���');
    Exit;
    end;

  Result.Dir := aJson['Dir'].AsString;
  SetLength(Result.FileList, aJson['FileLists'].AsArray.Length);
  for i:=0 to aJson['FileLists'].AsArray.Length-1 do
    Result.FileList[i] := aJson['FileLists'].AsArray[i].AsString;

  aJson.Clear();
  JsonStrings.Free;

  //��ȡ���ϴ��ļ���Ϣ��ɾ��picList.json�ļ�
  for i:=0 to 30 do
    begin
    delFlag := DeleteFile(PAnsiChar(AppPath + 'picList.json'));
    if not delFlag then WaitSomeTime(500) else Break;
    end;
  if not delFlag then TLogger.GetInstance.Error(FormatDateTime('YYYY-MM-DD hh:nn:ss',now) + '�ļ�[picList.json]ɾ��ʧ�ܡ�');
end;

function GetCurDialogPath(pathEdtHandle:HWND):string;//�������Ϊ�����ļ��Ի��򡱴����У���������·����ToolbarWindow32֮���������ֵΪ��ToolbarWindow32�����ĵ�ǰ·��
var curPath_arr: array[0..254] of Char;
    i:Integer;
begin
  GetWindowText(pathEdtHandle, @curPath_arr, SizeOf(curPath_arr));
  result := curPath_arr;
  i := Pos('��ַ:',result);
  if i>0 then Delete(result, i,5);
  result := Trim(result);
end;

//�ϴ�picList.json�е�ͼƬ�ļ�
procedure UpdatePicture;
var openDialog:HWND;//ͨ�����'#32770'�������ҵ����ļ��Ի���
    pathEdtHandle:HWND;//������ļ��Ի��򶥲���Edit�����Դ��л�ȡ�Ի���ǰ·��
    edtHandle:HWND;//�Ի����·���������д���ļ�����Edit�������������д·��������򿪰�ť�����л��Ի���ǰ·��
    btnHandle:HWND;//����򿪰�ť

    UpdateFileInfo:TUpdateFileInfo;//���ڱ�����Ҫ�ϴ����ļ�Ŀ¼�����ļ��б�
    curPath:string;//���ڱ��浱ǰ�򿪶Ի���ѡ���ĵ�ַ
    sameFlag:Boolean;
    temp:string;
    i:Integer;
begin
  //ʹ��spy++���� �Ӹ����ڲ���ȡ��"���ļ����Ի�����
  try
  openDialog := FindWindow('#32770','��');{�ҵ�����������ġ��򿪡��ļ��Ի���}
  if openDialog=0 then raise Exception.CreateFmt('%s:%s', [FormatDateTime('YYYY-MM-DD hh:nn:ss',now),'���ļ��Ի�����û���ҵ���']);


  //�ҵ���ʾ�Ի���ǰ·����Edit��
  pathEdtHandle := FindWindowEx(openDialog,0,'WorkerW',nil);
  pathEdtHandle := FindWindowEx(pathEdtHandle,0,'ReBarWindow32',nil);
  pathEdtHandle := FindWindowEx(pathEdtHandle,0,'Address Band Root',nil);
  pathEdtHandle := FindWindowEx(pathEdtHandle,0,'msctls_progress32',nil);
  pathEdtHandle := FindWindowEx(pathEdtHandle,0,'Breadcrumb Parent',nil);
  pathEdtHandle := FindWindowEx(pathEdtHandle,0,'ToolbarWindow32',nil);
  if pathEdtHandle=0 then raise Exception.CreateFmt('%s:%s', [FormatDateTime('YYYY-MM-DD hh:nn:ss',now),'���ļ��Ի���de��ǰ·�����û���ҵ���']);


  //��öԻ����·�������д�ļ�����Edit���л�·��Ҳ��ʹ�����
  edtHandle:= FindWindowEx(openDialog,0,'ComboBoxEx32',nil);
  edtHandle:= FindWindowEx(edtHandle,0,'ComboBox',nil);
  edtHandle:= FindWindowEx(edtHandle,0,'Edit',nil);
  if edtHandle=0 then raise Exception.CreateFmt('%s:%s', [FormatDateTime('YYYY-MM-DD hh:nn:ss',now),'���ļ��Ի���de��д·�����û���ҵ���']);

  //��öԻ����·��ġ�ȷ������ť
  btnHandle := FindWindowEx(openDialog,0,'Button',nil);
  if btnHandle=0 then raise Exception.CreateFmt('%s:%s', [FormatDateTime('YYYY-MM-DD hh:nn:ss',now),'���ļ��Ի���deȷ����ť���û���ҵ���']);

  //��Json�ļ��У���ȡҪ�ϴ����ļ��б��ļ�����Ŀ¼
  UpdateFileInfo := GetUpLoadFile();
  //ͳһ�����ȡ��"\��/"�Ա��ڱȽ�
  while IsPathDelimiter(UpdateFileInfo.Dir,Length(UpdateFileInfo.Dir)) do
    UpdateFileInfo.Dir := Copy(UpdateFileInfo.Dir,1,Length(UpdateFileInfo.Dir)-1);

  //��öԻ���ǰ����Ŀ¼
  curPath := GetCurDialogPath(pathEdtHandle);
  for i:=0 to 30 do
    begin
    //ȥ����ǰĿ¼�����"\/"��־���Ա��ڱȽ�
    while IsPathDelimiter(curPath,Length(curPath)) do
      curPath := Copy(curPath,1,Length(curPath)-1);

    //�л����ļ��Ի���ǰĿ¼���ϴ��ļ��б��Ŀ¼
    if curPath<>UpdateFileInfo.Dir then
      begin
      //�����ϴ��ļ����ڵ�Ŀ¼��Edit��
      SendMessage(edtHandle,WM_SETTEXT,255,Integer(PChar(UpdateFileInfo.Dir)));
      SendMessage(btnHandle,WM_LBUTTONDOWN,0,0); //���͡����¡���Ϣ
      SendMessage(btnHandle,WM_LBUTTONUP,0,0);   //���͡��ſ�����Ϣ
      //�ȴ�500���룬�ٽ�����һ���жϣ����Ի���ǰĿ¼�Ƿ��Ѿ��л�����Ҫ�ϴ��ļ�������Ŀ¼
      WaitSomeTime(500);
      end;
    //�ٴ�ˢ�¶Ի���ǰ����Ŀ¼
    curPath := GetCurDialogPath(pathEdtHandle);
    sameFlag := (curPath=UpdateFileInfo.Dir);
    if sameFlag then break;
    end;
    if not sameFlag then raise Exception.CreateFmt('%s:%s,ָ��Ŀ¼Ϊ��%s', [FormatDateTime('YYYY-MM-DD hh:nn:ss',now),'���ȷ����ť,�޷��л���ָ����Ŀ¼��',UpdateFileInfo.Dir]);

  //��ʱ���Ի���ǰĿ¼�Ѿ��л����ϴ��ļ�Ŀ¼����ʼ���·����ı������ļ����б��ļ�����Ҫ˫���ţ����Կո�Ϊ���
  temp := '';
  for i:=0 to Length(UpdateFileInfo.FileList)-1 do
    temp := temp + Format('"%s" ',[UpdateFileInfo.FileList[i]]);
  Delete(temp,Length(temp),1);
  SendMessage(edtHandle,WM_SETTEXT,255,Integer(PChar(temp)));
  //���ȷ����ť
  SendMessage(btnHandle,WM_LBUTTONDOWN,0,0); //���͡����¡���Ϣ
  SendMessage(btnHandle,WM_LBUTTONUP,0,0);   //���͡��ſ�����Ϣ
  TLogger.GetInstance.Info(FormatDateTime('YYYY-MM-DD hh:nn:ss',now)+'�ϴ�ͼƬ�ļ��ɹ���');
  except on e: Exception do
    TLogger.GetInstance.Error(e.message);
  end;

end;


begin
  Application.Initialize;
  AppPath := ExtractFilePath(Application.ExeName);
  doPropertiesConfiguration('log4delphi.properties'); //��ʼ����־�ؼ�
  UpdatePicture();
  //Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
