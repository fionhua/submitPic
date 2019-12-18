//使用方法：
//1.将要上传的文件列表按[eg.]的格式，生成picList.json文件，并保存到submitPic.exe所在目录
//2.调用调用submitPic.exe可执行文件，该文件将解析当前目录下picList.json文件，并找到“上传文件对话框”，将列表中的图片文件一次性在上传文件列表框中添加，并点击确定按钮

//eg.以下是picList.json文件示例，是需要上传的文件列表;
//每次上传完成后，将自动被删除;
//要所有需要被上传的文件，在同一目录。因为如果连带目录一次性填写多个待上传文件，可能会超过255字节长度

{
	"FileLists": [
		"woman01_01.png",
		"woman01_02.png",
		"woman01_03.png",
		"woman01_04.png",
		"woman01_05.png"
	],
	"Dir":"D:\\None\\原图\\woman01"
}