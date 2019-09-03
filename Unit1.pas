unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Layouts, FMX.ExtCtrls, FMX.Controls.Presentation, System.Actions,
  FMX.ActnList, FMX.ScrollBox, FMX.Memo,

  System.Permissions,  // ��Ҫ����
  System.Messaging, // ��Ҫ����

  Androidapi.JNI.Net, // ��Ҫ����
  Androidapi.JNI.GraphicsContentViewText, // ��Ҫ����
  Androidapi.JNI.JavaTypes, // ��Ҫ����
  Androidapi.Helpers, // ��Ҫ����
  Androidapi.JNI.App, // ��Ҫ����

  FMX.Objects, // ��Ҫ����
  FMX.StdActns, // ��Ҫ����
  FMX.MediaLibrary.Actions; // ��Ҫ����

type
  TForm1 = class(TForm)
    btnTakephoto: TCornerButton;
    ActionList1: TActionList;
    TakePhotoFromCameraAction1: TTakePhotoFromCameraAction;
    Memo1: TMemo;
    Layout1: TLayout;
    Imgprofile: TCircle;
    procedure btnTakephotoClick(Sender: TObject);
    procedure TakePhotoFromCameraAction1DidFinishTaking(Image: TBitmap);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    FMessageSubscriptionID: Integer;
    FPermissionCamera, FPermissionReadExternalStorage,
      FPermissionWriteExternalStorage: string;
    procedure DisplayRationale(Sender: TObject;
      const APermissions: TArray<string>; const APostRationaleProc: TProc);
    procedure TakePicturePermissionRequestResult(Sender: TObject;
      const APermissions: TArray<string>;
      const AGrantResults: TArray<TPermissionStatus>);
  public
    { Public declarations }
    procedure GetCropImage;

    // Activity����¼�
    function OnActivityResult(RequestCode, ResultCode: Integer;
      Data: JIntent): Boolean;
    // ��Ϣ�������
    procedure HandleActivityMessage(const Sender: TObject; const M: TMessage);
  end;

var
  Form1: TForm1;

implementation

uses
  System.IOUtils,

  Androidapi.JNI.Os,
  Androidapi.JNI.Support,
  Androidapi.JNI.Provider,
  Androidapi.JNIBridge,

  FMX.Surfaces,
  FMX.Helpers.Android,
  FMX.DialogService;

{$R *.fmx}

const
  IMAGE_TAKEPHOTO_FILENAME = 'mytakephoto.jpg';
  IMAGE_CROP_FILENAME = '/crop_small.jpg';
  Image_Crop_Code = 990;

var
  LUri: Jnet_Uri;

{$REGION '��̬��Ȩ��'}

  // Optional rationale display routine to display permission requirement rationale to the user
procedure TForm1.DisplayRationale(Sender: TObject;
  const APermissions: TArray<string>; const APostRationaleProc: TProc);
var
  I: Integer;
  RationaleMsg: string;
begin
  for I := 0 to High(APermissions) do
  begin
    if APermissions[I] = FPermissionCamera then
      RationaleMsg := RationaleMsg +
        'The app needs to access the camera to take a photo' + SLineBreak +
        SLineBreak
    else if APermissions[I] = FPermissionReadExternalStorage then
      RationaleMsg := RationaleMsg +
        'The app needs to read a photo file from your device';
  end;

  // Show an explanation to the user *asynchronously* - don't block this thread waiting for the user's response!
  // After the user sees the explanation, invoke the post-rationale routine to request the permissions
  TDialogService.ShowMessage(RationaleMsg,
    procedure(const AResult: TModalResult)
    begin
      APostRationaleProc;
    end)
end;

procedure TForm1.TakePicturePermissionRequestResult(Sender: TObject;
const APermissions: TArray<string>;
const AGrantResults: TArray<TPermissionStatus>);
begin
  // 3 permissions involved: CAMERA, READ_EXTERNAL_STORAGE and WRITE_EXTERNAL_STORAGE
  if (Length(AGrantResults) = 3) and
    (AGrantResults[0] = TPermissionStatus.Granted) and
    (AGrantResults[1] = TPermissionStatus.Granted) and
    (AGrantResults[2] = TPermissionStatus.Granted) then
  begin
    TakePhotoFromCameraAction1.Execute;
  end
  else
    TDialogService.ShowMessage
      ('Cannot take a photo because the required permissions are not all granted')
end;
{$ENDREGION}

procedure TForm1.FormCreate(Sender: TObject);
begin
  Memo1.Lines.Add('ֻ��� Android 8.0 ����');
  Memo1.Lines.Add('��Ϊ Mate8.0 + Android 8.0 ����ͨ��');
  // Model name
  Memo1.Lines.Add(JStringToString(TJBuild.JavaClass.MODEL));
  // Os Version
  Memo1.Lines.Add(JStringToString(TJBuild_VERSION.JavaClass.RELEASE));

end;

// ��Ϣ�������
procedure TForm1.HandleActivityMessage(const Sender: TObject;
const M: TMessage);
begin
  if M is TMessageResultNotification then
    OnActivityResult(TMessageResultNotification(M).RequestCode,
      TMessageResultNotification(M).ResultCode,
      TMessageResultNotification(M).Value);

end;

procedure TForm1.TakePhotoFromCameraAction1DidFinishTaking(Image: TBitmap);
begin
  Image.SaveToFile(System.IOUtils.TPath.GetPublicPath + PathDelim +
    IMAGE_TAKEPHOTO_FILENAME);
  GetCropImage;
end;

procedure TForm1.btnTakephotoClick(Sender: TObject);
begin
  FPermissionCamera := JStringToString(TJManifest_permission.JavaClass.CAMERA);
  FPermissionReadExternalStorage :=
    JStringToString(TJManifest_permission.JavaClass.READ_EXTERNAL_STORAGE);
  FPermissionWriteExternalStorage :=
    JStringToString(TJManifest_permission.JavaClass.WRITE_EXTERNAL_STORAGE);

  PermissionsService.RequestPermissions
    ([FPermissionCamera, FPermissionReadExternalStorage,
    FPermissionWriteExternalStorage], TakePicturePermissionRequestResult,
    DisplayRationale)
end;

procedure TForm1.GetCropImage;
var
  Intent: JIntent;
  LFileName, LDestFileName: string;
  LData: Jnet_Uri;
  LFile: JFile;
begin
  Memo1.Lines.Clear;
  FMessageSubscriptionID := TMessageManager.DefaultManager.SubscribeToMessage
    (TMessageResultNotification, HandleActivityMessage);

  LFileName := System.IOUtils.TPath.GetPublicPath + PathDelim +
    IMAGE_TAKEPHOTO_FILENAME;
  LDestFileName := TPath.GetDownloadsPath + PathDelim +
    IMAGE_TAKEPHOTO_FILENAME;
  TFile.Copy(LFileName, LDestFileName, True); // ����ͼƬ��ָ��Ŀ¼

  Intent := TJIntent.Create;
  if TJBuild_VERSION.JavaClass.SDK_INT >= TJBuild_VERSION_CODES.JavaClass.N then
  begin
    LFile := TJFile.JavaClass.init(StringToJString(LFileName));
    Intent.addFlags(TJIntent.JavaClass.FLAG_GRANT_READ_URI_PERMISSION);
    Intent.addFlags(TJIntent.JavaClass.FLAG_GRANT_WRITE_URI_PERMISSION);
    LData := TJFileProvider.JavaClass.getUriForFile(TAndroidHelper.Context,
      StringToJString(JStringToString(TAndroidHelper.Context.getPackageName()) +
      '.fileprovider'), LFile);
  end
  else
    LData := TJnet_Uri.JavaClass.parse
      (StringToJString('file://' + LDestFileName));

  LUri := TJnet_Uri.JavaClass.parse
    (StringToJString('file://' + System.IOUtils.TPath.GetPublicPath + PathDelim
    + IMAGE_CROP_FILENAME));

  // ����ϵͳ�Ĳ��� ACTION
  Intent.setAction(StringToJString('com.android.camera.action.CROP'));
  Intent.setDataAndType(LData, StringToJString('image/*'));

  // ���òü�
  Intent.putExtra(StringToJString('crop'), True);

  // aspectX aspectY �ǿ�ߵı���
  Intent.putExtra(StringToJString('aspectX'), 1);
  Intent.putExtra(StringToJString('aspectY'), 1);

  // outputX outputY �ǲü�ͼƬ���
  Intent.putExtra(StringToJString('outputX'), 350);
  Intent.putExtra(StringToJString('outputY'), 350);

  Intent.putExtra(TJMediaStore.JavaClass.EXTRA_OUTPUT,
    TJParcelable.Wrap((LUri as ILocalObject).GetObjectID));

  // True:����data������ JBitmap��False��ֻ����uri
  // True �ڴ�ߴ�ʱ���ˡ�����
  Intent.putExtra(StringToJString('return-data'), False);

  // Intent.putExtra(StringToJString('outputFormat'),
  // TJBitmap_CompressFormat.JavaClass.JPEG.toString);

  // ȡ������ʶ��
  // Intent.putExtra(StringToJString('noFaceDetection'), True);

  try
    TAndroidHelper.Activity.StartActivityForResult(Intent, Image_Crop_Code);
  except
    on E: Exception do
    begin
      Memo1.Lines.Add(E.Message);
    end;

  end;
end;

// Activity ����¼�
function TForm1.OnActivityResult(RequestCode, ResultCode: Integer;
Data: JIntent): Boolean;
var
  JBmp: JBitmap;
  BitmapSurface: TBitmapSurface;
begin
  Result := False;

  TMessageManager.DefaultManager.Unsubscribe(TMessageResultNotification,
    FMessageSubscriptionID);
  FMessageSubscriptionID := 0;

  // �ж��Զ����������
  if RequestCode = Image_Crop_Code then
  begin
    Memo1.Lines.Add('��������');
    // �������ȷ��
    if ResultCode = TJActivity.JavaClass.RESULT_OK then
    begin
      // �Ƿ�������
      if Assigned(Data) then
      begin
        Memo1.Lines.Add('�����ݣ���Ҫȥ����');
        // ����������
        try
          JBmp := TJBitmapFactory.JavaClass.decodeStream(
          // TAndroidHelper.Context.getContentResolver.openInputStream(LUri)
          TAndroidHelper.ContentResolver.openInputStream(LUri));

          Memo1.Lines.Add('����ͼƬ�Ĵ�С(W/H)�� ' + JBmp.getWidth.ToString + 'x' +
            JBmp.getHeight.ToString + ' ����');

          BitmapSurface := TBitmapSurface.Create;
          JBitmapToSurface(JBmp, BitmapSurface);
          Imgprofile.Fill.Bitmap.Bitmap.Assign(BitmapSurface);
          BitmapSurface.Free;

          Memo1.Lines.Add('��ȡ�ü�ͼƬ���');
        except
          on E: Exception do
          begin
            Memo1.Lines.Add('OOooop!���ؽ��ʱ����' + E.Message);
          end;
        end;
      end;
    end
    else if ResultCode = TJActivity.JavaClass.RESULT_CANCELED then
    begin
      Memo1.Lines.Add('����ȡ��');
    end;
    Result := True;
  end;
end;

end.
