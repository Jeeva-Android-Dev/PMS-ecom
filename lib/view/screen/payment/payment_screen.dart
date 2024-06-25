import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_sixvalley_ecommerce/localization/language_constrants.dart';
import 'package:flutter_sixvalley_ecommerce/utill/app_constants.dart';
import 'package:flutter_sixvalley_ecommerce/view/basewidget/animated_custom_dialog.dart';
import 'package:flutter_sixvalley_ecommerce/view/basewidget/my_dialog.dart';
import 'package:flutter_sixvalley_ecommerce/view/screen/dashboard/dashboard_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

class PaymentScreen extends StatefulWidget {
  final String addressID;
  final String billingId;
  final String? orderNote;
  final String customerID;
  final String couponCode;
  final String? couponCodeAmount;
  final String? paymentMethod;

  const PaymentScreen({Key? key, required this.addressID, required this.customerID, required this.couponCode, required this.billingId, this.orderNote, this.couponCodeAmount, this.paymentMethod}) : super(key: key);

  @override
  PaymentScreenState createState() => PaymentScreenState();
}

class PaymentScreenState extends State<PaymentScreen> {
  String? selectedUrl;
  double value = 0.0;
  final bool _isLoading = true;

  late WebViewController controllerGlobal;
  PullToRefreshController? pullToRefreshController;
  late MyInAppBrowser browser;

  @override
  void initState() {
    super.initState();
    selectedUrl = '${AppConstants.baseUrl}/customer/payment-mobile?customer_id='
        '${widget.customerID}&address_id=${widget.addressID}&coupon_code='
        '${widget.couponCode}&coupon_discount=${widget.couponCodeAmount}&billing_address_id=${widget.billingId}&order_note=${widget.orderNote}&payment_method=${widget.paymentMethod}';
    if (kDebugMode) {
      print(selectedUrl);
    }

    _initData();
  }

  void _initData() async {
    browser = MyInAppBrowser(context);
    if (Platform.isAndroid) {
      await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);

      bool swAvailable = await AndroidWebViewFeature.isFeatureSupported(AndroidWebViewFeature.SERVICE_WORKER_BASIC_USAGE);
      bool swInterceptAvailable = await AndroidWebViewFeature.isFeatureSupported(AndroidWebViewFeature.SERVICE_WORKER_SHOULD_INTERCEPT_REQUEST);

      if (swAvailable && swInterceptAvailable) {
        AndroidServiceWorkerController serviceWorkerController = AndroidServiceWorkerController.instance();
        await serviceWorkerController.setServiceWorkerClient(AndroidServiceWorkerClient(
          shouldInterceptRequest: (request) async {
            if (kDebugMode) {
              print(request);
            }
            return null;
          },
        ));
      }
    }

    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.black,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          browser.webViewController.reload();
        } else if (Platform.isIOS) {
          browser.webViewController.loadUrl(urlRequest: URLRequest(url: await browser.webViewController.getUrl()));
        }
      },
    );
    browser.pullToRefreshController = pullToRefreshController;

    await browser.openUrlRequest(
      urlRequest: URLRequest(url: Uri.parse(selectedUrl!)),
      options: InAppBrowserClassOptions(
        inAppWebViewGroupOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(useShouldOverrideUrlLoading: true, useOnLoadResource: true),
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _exitApp(context),
      child: Scaffold(
        appBar: AppBar(title: const Text(''),backgroundColor: Theme.of(context).cardColor),
        body: Center(
          child: Column(
            children: [

              Stack(
                children: [
                  _isLoading ? Center(
                    child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
                  ) : const SizedBox.shrink(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _exitApp(BuildContext context) async {
    if (await controllerGlobal.canGoBack()) {
      controllerGlobal.goBack();
      return Future.value(false);
    } else {
      if(context.mounted){}
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const DashBoardScreen()), (route) => false);
      showAnimatedDialog(context, MyDialog(
        icon: Icons.clear,
        title: getTranslated('payment_cancelled', context),
        description: getTranslated('your_payment_cancelled', context),
        isFailed: true,
      ), dismissible: false, isFlip: true);
      return Future.value(true);
    }
  }
}
class MyInAppBrowser extends InAppBrowser {

  final BuildContext context;

  MyInAppBrowser(this.context, {
    int? windowId,
    UnmodifiableListView<UserScript>? initialUserScripts,
  })
      : super(windowId: windowId, initialUserScripts: initialUserScripts);

  bool _canRedirect = true;

  @override
  Future onBrowserCreated() async {
    if (kDebugMode) {
      print("\n\nBrowser Created!\n\n");
    }
  }

  @override
  Future onLoadStart(url) async {
    if (kDebugMode) {
      print("\n\nStarted: $url\n\n");
    }
    _pageRedirect(url.toString());
  }

  @override
  Future onLoadStop(url) async {
    pullToRefreshController?.endRefreshing();
    if (kDebugMode) {
      print("\n\nStopped: $url\n\n");
    }
    _pageRedirect(url.toString());
  }

  @override
  void onLoadError(url, code, message) {
    pullToRefreshController?.endRefreshing();
    if (kDebugMode) {
      print("Can't load [$url] Error: $message");
    }
  }

  @override
  void onProgressChanged(progress) {
    if (progress == 100) {
      pullToRefreshController?.endRefreshing();
    }
    if (kDebugMode) {
      print("Progress: $progress");
    }
  }

  @override
  void onExit() {
    if(_canRedirect) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(
          builder: (_) => const DashBoardScreen()), (route) => false);



      showAnimatedDialog(context, MyDialog(
        icon: Icons.clear,
        title: getTranslated('payment_failed', context),
        description: getTranslated('your_payment_failed', context),
        isFailed: true,
      ), dismissible: false, isFlip: true);
    }

    if (kDebugMode) {
      print("\n\nBrowser closed!\n\n");
      print("payment failed by m oni");
    }
  }

  @override
  Future<NavigationActionPolicy> shouldOverrideUrlLoading(navigationAction) async {
    if (kDebugMode) {
      print("\n\nOverride ${navigationAction.request.url}\n\n");
    }
    return NavigationActionPolicy.ALLOW;
  }

  @override
  void onLoadResource(resource) {
    // print("Started at: " + response.startTime.toString() + "ms ---> duration: " + response.duration.toString() + "ms " + (response.url ?? '').toString());
  }

  @override
  void onConsoleMessage(consoleMessage) {
    if (kDebugMode) {
      print("""
    console output:
      message: ${consoleMessage.message}
      messageLevel: ${consoleMessage.messageLevel.toValue()}
   """);
    }
  }

  Future<void> _pageRedirect(String url) async {

    if(_canRedirect) {

      bool isSuccess = url.contains('payment-success') ;
      bool isFailed = url.contains('payment-fail') ;
      bool isCancel = url.contains('cancel') && url.contains(AppConstants.baseUrl);
      _verifyPaymentStatus(url);
      if (kDebugMode) {
        print('isSuccess: $isSuccess, isFailed: $isFailed, isCancel: $isCancel');
      }

      if(isSuccess || isFailed || isCancel) {
        _canRedirect = false;
        close();
        // _verifyPaymentStatus(url);

      }
      if(isSuccess){
        if (kDebugMode) {
          print('Handling success case');
        }
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(
            builder: (_) => const DashBoardScreen()), (route) => false);


        showAnimatedDialog(context, MyDialog(
          icon: Icons.done,
          title: getTranslated('payment_done', context),
          description: getTranslated('your_payment_successfully_done', context),
        ), dismissible: false, isFlip: true);
        if(kDebugMode){
          print("payment success by m oni");

        }

      }else if(isFailed) {
        if (kDebugMode) {
          print('Handling cancel case');
        }

        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(
            builder: (_) => const DashBoardScreen()), (route) => false);



        showAnimatedDialog(context, MyDialog(
          icon: Icons.clear,
          title: getTranslated('payment_failed', context),
          description: getTranslated('your_payment_failed', context),
          isFailed: true,
        ), dismissible: false, isFlip: true);


      }else if(isCancel) {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(
            builder: (_) => const DashBoardScreen()), (route) => false);


        showAnimatedDialog(context, MyDialog(
          icon: Icons.clear,
          title: getTranslated('payment_cancelled', context),
          description: getTranslated('your_payment_cancelled', context),
          isFailed: true,
        ), dismissible: false, isFlip: true);

      }
    }

  }

  void _verifyPaymentStatus(String url) async {
    // Perform a network request using a package like http or dio
    // Example using the http package
    Uri uri = Uri.parse(url);
    final response = await http.get(uri);
    if (kDebugMode) {
      print('hitted verifypayment ');

    }
    if (response.statusCode == 200) {
      if (kDebugMode) {
        print('Handling success code 200');

      }
      // Check the response content for success or failure
      if (response.body.contains('Payment succeeded')) {
        // Handle successful payment
        //_redirectBackToApp();

        if (kDebugMode) {
          print('Handling success response');

        }
        print('Response status code: ${response.statusCode}');
        print('Response body: ${response.body}');


      } else if(response.body.contains('Payment failed'))  {
        // Handle failed payment
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashBoardScreen()),
              (route) => false,
        );

      }
    } else {
      // Handle error in network request
      if (kDebugMode) {
        print('Error in network request: ${response.statusCode}');
      }
    }
  }

  void _redirectBackToApp() {
    print('Redirecting back to the app');
    print('Showing dialog');
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(
        builder: (_) => const DashBoardScreen()), (route) => false);

    print('Showing dialog');
    Future.delayed(const Duration(milliseconds: 100), () {
      showAnimatedDialog(context, MyDialog(
        icon: Icons.done,
        title: getTranslated('payment_done', context),
        description: getTranslated('your_payment_successfully_done', context),
      ), dismissible: false, isFlip: true);
      if(kDebugMode){
        print("Payment redirected by moni");
      }
    });
  }
  }


