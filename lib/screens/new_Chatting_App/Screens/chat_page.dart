import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flash_chat/screens/Common/additional/constants.dart';
import 'package:flash_chat/screens/Common/screens/welcome_screen.dart';
import 'package:flash_chat/screens/new_Chatting_App/additional/providers/auth_provider.dart';
import 'package:flash_chat/screens/new_Chatting_App/additional/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'open_full_photo.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:modal_progress_hud/modal_progress_hud.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../additional/message.dart';
import '../additional/providers/chat_provider.dart';

class ChatPage extends StatefulWidget {
  static String id = 'chat_page';
  String peerId;
  String peerAvatar;
  String peerNickname;

  ChatPage(
      {Key key,
      @required this.peerAvatar,
      @required this.peerId,
      @required this.peerNickname})
      : super(key: key);

  @override
  State createState() => ChatPageState(
        peerId: this.peerId,
        peerAvatar: this.peerAvatar,
        peerNickname: this.peerNickname,
      );
}

class ChatPageState extends State<ChatPage> {
  ChatPageState({Key key, this.peerAvatar, this.peerId, this.peerNickname});

  String peerId;
  String peerAvatar;
  String peerNickname;
  String currentUserId;

  List<QueryDocumentSnapshot> listMessage = new List.from([]);

  int _limit = 20;
  int _limitIncrement = 20;
  String groupChatId = "";

  File imageFile;
  bool isLoading = false;
  bool isShowSticker = false;
  String imageUrl = "";

  final TextEditingController textEditingController = TextEditingController();
  final ScrollController listScrollController = ScrollController();
  final FocusNode focusNode = FocusNode();

  ChatProvider chatProvider;
  AuthProvider authProvider;

  @override
  void initState() {
    super.initState();
    chatProvider = context.read<ChatProvider>();
    authProvider = context.read<AuthProvider>();

    focusNode.addListener(onFocusChange);
    listScrollController.addListener(_scrollListner);
    readLocal();
  }

  _scrollListner() {
    if (listScrollController.offset >=
            listScrollController.position.maxScrollExtent &&
        !listScrollController.position.outOfRange) {
      setState(() {
        _limit += _limitIncrement;
      });
    }
  }

  void onFocusChange() {
    if (focusNode.hasFocus) {
      setState(() {
        isShowSticker = false;
      });
    }
  }

  void readLocal() {
    if (authProvider.getUserFirebaseId().isNotEmpty == true) {
      currentUserId = authProvider.getUserFirebaseId();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => WelcomeScreen()),
          (Route<dynamic> route) => false);
    }
    if (currentUserId.hashCode <= peerId.hashCode) {
      groupChatId = '$currentUserId-$peerId';
    } else {
      groupChatId = '$peerId-$currentUserId';
    }

    chatProvider.updateDataFirestore(FirebaseConstants.pathUserCollection,
        currentUserId, {FirebaseConstants.chattingWith: peerId});
  }

  Future getImage() async {
    ImagePicker imagePicker = ImagePicker();
    PickedFile pickedFile;

    pickedFile = await imagePicker.getImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      imageFile = File(pickedFile.path);
      if (imageFile != null) {
        setState(() {
          isLoading = true;
        });
        uploadFile();
      }
    }
  }

  void getSticker() {
    focusNode.unfocus();
    setState(() {
      isShowSticker = !isShowSticker;
    });
  }

  Future uploadFile() async {
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    UploadTask uploadTask = chatProvider.uploadTask(imageFile, fileName);
    try {
      TaskSnapshot snapshot = await uploadTask;
      imageUrl = await snapshot.ref.getDownloadURL();
      setState(() {
        isLoading = false;
        onSendMessage(imageUrl, TypeMessage.image);
      });
    } on FirebaseException catch (e) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: e.message ?? e.toString());
    }
  }

  void onSendMessage(String content, int type) {
    if (content.trim().isNotEmpty) {
      textEditingController.clear();
      chatProvider.sendMessage(
          content, type, groupChatId, currentUserId, peerId);
      listScrollController.animateTo(0,
          duration: Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      Fluttertoast.showToast(
          msg: 'Nothing to Send', backgroundColor: Colors.grey);
    }
  }

  bool isLastMessageLeft(int index) {
    if ((index > 0 &&
            listMessage[index - 1].get(FirebaseConstants.idFrom) ==
                currentUserId) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  bool isLastMessageRight(int index) {
    if ((index > 0 &&
            listMessage[index - 1].get(FirebaseConstants.idFrom) !=
                currentUserId) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> onBckPress() {
    if (isShowSticker) {
      setState(() {
        isShowSticker = false;
      });
    } else {
      chatProvider.updateDataFirestore(FirebaseConstants.pathUserCollection,
          currentUserId, {FirebaseConstants.chattingWith: null});
      Navigator.pop(context);
    }
    return Future.value(false);
  }

  void _oncallPhone(String callPhoneNumber) async {
    var url = 'tel://$callPhoneNumber';
    if (await canLaunch(url)) {
      await launch(url);
    } else
      throw Fluttertoast.showToast(msg: 'Error Occured');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: whiteColor,
      appBar: AppBar(
        backgroundColor: lightBLueColor,
        iconTheme: IconThemeData(color: whiteColor),
        title: Text(
          this.peerNickname,
          style: TextStyle(color: whiteColor),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.phone_iphone,
              size: 30,
              color: whiteColor,
            ),
            onPressed: () {
              SettingProvider settingProvider;
              settingProvider = context.read<SettingProvider>();
              String callPhoneNumber =
                  settingProvider.getPref(FirebaseConstants.phoneNumber) ?? "";
              _oncallPhone(callPhoneNumber);
            },
          )
        ],
      ),
      body: WillPopScope(
        child: Stack(
          children: [
            Column(
              children: [
                buildListMessage(),
                isShowSticker ? buildSticker() : SizedBox.shrink(),
                buildInput(),
              ],
            ),
            buildLoading(), //TODO: here i have to make it implementable it is giving an error
          ],
        ),
        onWillPop: onBckPress,
      ),
    );
  }

  Widget buildSticker() {
    return Expanded(
        child: Container(
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
          color: whiteColor),
      padding: EdgeInsets.all(5),
      height: 180,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              StickerImplementation(
                stickerTouchFunction: () =>
                    onSendMessage('mimi1', TypeMessage.sticker),
                stickerName: 'mimi1',
              ),
              StickerImplementation(
                  stickerTouchFunction: () =>
                      onSendMessage('mimi2', TypeMessage.sticker),
                  stickerName: 'mimi2'),
              StickerImplementation(
                  stickerTouchFunction: () =>
                      onSendMessage('mimi3', TypeMessage.sticker),
                  stickerName: 'mimi3'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              StickerImplementation(
                  stickerTouchFunction: () =>
                      onSendMessage('mimi4', TypeMessage.sticker),
                  stickerName: 'mimi4'),
              StickerImplementation(
                  stickerTouchFunction: () =>
                      onSendMessage('mimi5', TypeMessage.sticker),
                  stickerName: 'mimi5'),
              StickerImplementation(
                  stickerTouchFunction: () =>
                      onSendMessage('mimi6', TypeMessage.sticker),
                  stickerName: 'mimi6'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              StickerImplementation(
                  stickerTouchFunction: () =>
                      onSendMessage('mimi7', TypeMessage.sticker),
                  stickerName: 'mimi7'),
              StickerImplementation(
                  stickerTouchFunction: () =>
                      onSendMessage('mimi8', TypeMessage.sticker),
                  stickerName: 'mimi8'),
              StickerImplementation(
                  stickerTouchFunction: () =>
                      onSendMessage('mimi9', TypeMessage.sticker),
                  stickerName: 'mimi9'),
            ],
          )
        ],
      ),
    ));
  }

  Widget buildLoading() {
    return Positioned(
        child: isLoading
            ? Container(
                color: Colors.black87,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.grey,
                  ),
                ),
              )
            : SizedBox.shrink());
  }

  Widget buildInput() {
    return Container(
      child: Row(
        children: <Widget>[
          Material(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 1),
              child: IconButton(
                icon: Icon(Icons.camera_enhance),
                onPressed: getImage,
                color: lightBLueColor,
              ),
            ),
            color: whiteColor,
          ),
          Material(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 1),
              child: IconButton(
                icon: Icon(Icons.face_retouching_natural),
                onPressed: getSticker,
                color: lightBLueColor,
              ),
            ),
            color: whiteColor,
          ),
          Flexible(
            child: Container(
              child: TextField(
                onSubmitted: (value) {
                  onSendMessage(textEditingController.text, TypeMessage.text);
                },
                style: TextStyle(color: lightBLueColor, fontSize: 15),
                controller: textEditingController,
                decoration: InputDecoration.collapsed(
                    hintText: 'Type your message...',
                    hintStyle: TextStyle(color: Colors.grey)),
                focusNode: focusNode,
              ),
            ),
          ),
          Material(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 8),
              child: IconButton(
                icon: Icon(Icons.send),
                onPressed: () =>
                    onSendMessage(textEditingController.text, TypeMessage.text),
                color: lightBLueColor,
              ),
            ),
            color: whiteColor,
          ),
        ],
      ),
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black38, width: 0.5)),
          color: whiteColor),
    );
  }

  Widget buildItem(int index, DocumentSnapshot document) {
    if (document != null) {
      MessageChat messageChat = MessageChat.fromDocument(document);
      if (messageChat.idFrom == currentUserId) {
        return Row(
          children: <Widget>[
            messageChat.type == TypeMessage.text
                ? Container(
                    child: Text(
                      messageChat.content,
                      style: TextStyle(color: lightBLueColor),
                    ),
                    padding: EdgeInsets.fromLTRB(15, 10, 15, 10),
                    width: 200,
                    decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(8)),
                    margin: EdgeInsets.only(
                        bottom: isLastMessageRight(index) ? 20 : 10, right: 10),
                  )
                : messageChat.type == TypeMessage.image
                    ? Container(
                        margin: EdgeInsets.only(
                            bottom: isLastMessageRight(index) ? 20 : 10,
                            right: 10),
                        child: OutlinedButton(
                          style: ButtonStyle(
                              padding: MaterialStateProperty.all<EdgeInsets>(
                                  EdgeInsets.all(0))),
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => FullPhotoView(
                                        url: messageChat.content)));
                          },
                          child: Material(
                            borderRadius: BorderRadius.circular(8),
                            clipBehavior: Clip.hardEdge,
                            child: Image.network(
                              messageChat.content,
                              height: 200,
                              width: 200,
                              fit: BoxFit.cover,
                              loadingBuilder: (BuildContext context,
                                  Widget child,
                                  ImageChunkEvent loadingProgress) {
                                if (loadingProgress == null) {
                                  return child;
                                }
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  width: 200,
                                  height: 200,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: lightBLueColor,
                                      value: loadingProgress
                                                      .expectedTotalBytes !=
                                                  null &&
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                          ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, object, stackTrace) {
                                return Material(
                                  child: Image.asset(
                                    'images/img_not_new.jpg',
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(8),
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                );
                              },
                            ),
                          ),
                        ),
                      )
                    : Container(
                        child: Image.asset(
                          'images/${messageChat.content}.gif',
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                        margin: EdgeInsets.only(
                            bottom: isLastMessageRight(index) ? 20 : 10,
                            right: 10),
                      ),
          ],
          mainAxisAlignment: MainAxisAlignment.end,
        );
      } else {
        return Container(
          child: Column(
            children: <Widget>[
              Row(
                children: [
                  isLastMessageLeft(index)
                      ? Material(
                          child: Image.network(
                            peerAvatar,
                            loadingBuilder: (BuildContext context, Widget child,
                                ImageChunkEvent loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  color: lightBLueColor,
                                  value: loadingProgress.expectedTotalBytes !=
                                              null &&
                                          loadingProgress.expectedTotalBytes !=
                                              null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes
                                      : null,
                                ),
                              );
                            },
                            width: 35,
                            height: 35,
                            fit: BoxFit.cover,
                            errorBuilder: (context, object, stackTrace) {
                              return Icon(
                                Icons.account_circle,
                                size: 35,
                                color: Colors.grey,
                              );
                            },
                          ),
                          borderRadius: BorderRadius.circular(18),
                          clipBehavior: Clip.hardEdge,
                        )
                      : Container(
                          width: 35,
                        ),
                  messageChat.type == TypeMessage.text
                      ? Container(
                          child: Text(
                            messageChat.content,
                            style: TextStyle(
                              color: whiteColor,
                            ),
                          ),
                          padding: EdgeInsets.fromLTRB(15, 10, 15, 10),
                          width: 200,
                          decoration: BoxDecoration(
                              color: lightBLueColor,
                              borderRadius: BorderRadius.circular(8)),
                          margin: EdgeInsets.only(left: 10),
                        )
                      : messageChat.type == TypeMessage.image
                          ? Container(
                              margin: EdgeInsets.only(left: 10),
                              child: TextButton(
                                style: ButtonStyle(
                                    padding:
                                        MaterialStateProperty.all<EdgeInsets>(
                                            EdgeInsets.all(0))),
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => FullPhotoView(
                                              url: messageChat.content)));
                                },
                                child: Material(
                                  borderRadius: BorderRadius.circular(8),
                                  clipBehavior: Clip.hardEdge,
                                  child: Image.network(
                                    messageChat.content,
                                    height: 200,
                                    width: 200,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (BuildContext context,
                                        Widget child,
                                        ImageChunkEvent loadingProgress) {
                                      if (loadingProgress == null) {
                                        return child;
                                      }
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black38,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        width: 200,
                                        height: 200,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: lightBLueColor,
                                            value: loadingProgress
                                                            .expectedTotalBytes !=
                                                        null &&
                                                    loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder:
                                        (context, object, stackTrace) =>
                                            Material(
                                                child: Image.asset(
                                      'images/img_not_new.jpg',
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    )),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              child: Image.asset(
                                'images/${messageChat.content}.gif',
                                height: 200,
                                width: 200,
                                fit: BoxFit.cover,
                              ),
                              margin: EdgeInsets.only(
                                  left: isLastMessageRight(index) ? 20 : 10,
                                  right: 10),
                            )
                ],
              ),
              isLastMessageLeft(index)
                  ? Container(
                      child: Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(
                            DateTime.fromMillisecondsSinceEpoch(
                                int.parse(messageChat.timeStamp))),
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontStyle: FontStyle.italic),
                      ),
                      margin: EdgeInsets.only(left: 50, top: 5, bottom: 5),
                    )
                  : SizedBox.shrink()
            ],
            crossAxisAlignment: CrossAxisAlignment.start,
          ),
          margin: EdgeInsets.only(bottom: 10),
        );
      }
    } else {
      return SizedBox.shrink();
    }
  }

  Widget buildListMessage() {
    return Flexible(
        child: groupChatId.isNotEmpty
            ? StreamBuilder<QuerySnapshot>(
                stream: chatProvider.getChatStream(groupChatId, _limit),
                builder: (BuildContext context,
                    AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.hasData) {
                    listMessage.addAll(snapshot.data.docs);
                    return ListView.builder(
                      padding: EdgeInsets.all(10),
                      itemBuilder: (context, index) =>
                          buildItem(index, snapshot.data.docs[index]),
                      itemCount: snapshot.data.docs.length,
                      reverse: true,
                      controller: listScrollController,
                    );
                  } else {
                    return Center(
                      child: CircularProgressIndicator(
                        color: lightBLueColor,
                      ),
                    );
                  }
                })
            : Center(
                child: CircularProgressIndicator(
                  color: lightBLueColor,
                ),
              ));
  }
}

class StickerImplementation extends StatelessWidget {
  Function stickerTouchFunction;
  String stickerName;

  StickerImplementation(
      {@required this.stickerTouchFunction, @required this.stickerName});

  Widget build(BuildContext context) {
    return TextButton(
        onPressed: stickerTouchFunction,
        child: Image.asset(
          'images/$stickerName.gif',
          width: 50,
          height: 50,
          fit: BoxFit.cover,
        ));
  }
}
