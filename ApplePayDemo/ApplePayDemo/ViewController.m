//
//  ViewController.m
//  ApplePayDemo
//
//  Created by 吴亚乾 on 16/2/29.
//  Copyright © 2016年 吴亚乾. All rights reserved.
//

#import "ViewController.h"
#import <PassKit/PassKit.h>
#import <AddressBook/AddressBook.h>

@interface ViewController ()<PKPaymentAuthorizationViewControllerDelegate>
{
    NSMutableArray *_summaryItems;
    NSMutableArray *_shippingMethods;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (IBAction)ApplePayBtnDidClicked:(id)sender
{
    // PKPaymentAuthorizationViewController需要iOS8.0以上版本
    if (![PKPaymentAuthorizationViewController class]) {
        NSLog(@"操作系统不支持ApplePay，请升级至9.0以上版本，且iPhone6以上设备才支持");
        return;
    }
    // 检查当前设备是否支持支付
    if (![PKPaymentAuthorizationViewController canMakePayments]) {
        //支付需iOS9.0以上支持
        NSLog(@"设备不支持ApplePay，请升级至9.0以上版本，且iPhone6以上设备才支持");
        return;
    }
    
    // 检查用户是否支持，Amex、MasterCard、Visa与银联四种卡，可根据需求进行更改
    NSArray *supportNetWorks = @[PKPaymentNetworkAmex,PKPaymentNetworkMasterCard,PKPaymentNetworkVisa,PKPaymentNetworkChinaUnionPay];
    if (![PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:supportNetWorks]) {
        NSLog(@"没有绑定银行卡");
        return;
    }

    // 支付请求对象(信息传递者)
    PKPaymentRequest *request = [[PKPaymentRequest alloc] init];
    // 商品
    NSDecimalNumber *subTotal = [NSDecimalNumber decimalNumberWithString:@"13.14"];
    PKPaymentSummaryItem *goodsItem = [PKPaymentSummaryItem summaryItemWithLabel:@"商品价格"
                                                                          amount:subTotal];
    
    NSDecimalNumber *prime = [NSDecimalNumber decimalNumberWithString:@"-13.13"];
    PKPaymentSummaryItem *primeRate = [PKPaymentSummaryItem summaryItemWithLabel:@"优惠折扣"
                                                                          amount:prime];

    NSDecimalNumber *shipMethodPrime = [NSDecimalNumber zero];
    PKPaymentSummaryItem *shipMethod = [PKPaymentSummaryItem summaryItemWithLabel:@"包邮"
                                                                           amount:shipMethodPrime];
    
    // 最终价格
    NSDecimalNumber *totalPrice = [NSDecimalNumber zero];
    totalPrice = [totalPrice decimalNumberByAdding:subTotal];
    totalPrice = [totalPrice decimalNumberByAdding:prime];
    totalPrice = [totalPrice decimalNumberByAdding:shipMethodPrime];
    
    PKPaymentSummaryItem *finally = [PKPaymentSummaryItem summaryItemWithLabel:@"十三先生"
                                                                        amount:totalPrice
                                                                          type:PKPaymentSummaryItemTypeFinal];
    // summaryItems为账单列表(即界面上显示的商品)，类型是 NSMutableArray，这里设置成成员变量，在后续的代理回调中可以进行支付金额的调整。
    _summaryItems = [NSMutableArray arrayWithArray:@[goodsItem,primeRate,shipMethod,finally]];
    request.paymentSummaryItems = _summaryItems;
    
    // 指定国家编码、币种
    request.countryCode = @"CN";
    request.currencyCode = @"CNY";
    
    // ApplePay申请的merchantID
    request.merchantIdentifier = @"merchant.com.wuyaqianApplePayDemo";
    
    // 设置支持的交易处理协议，3DS必须支持，EMV为可选，目前国内的话还是使用两者吧
    request.merchantCapabilities = PKMerchantCapabilityEMV|PKMerchantCapability3DS;
    
    // 用户可进行支付的银行卡
    request.supportedNetworks = supportNetWorks;
    
    // 如果需要邮寄账单可以选择进行设置，默认PKAddressFieldNone(不邮寄账单)
    // requiredBillingAddressFields 是个枚举值
    // 送货地址信息，这里设置需要地址和联系方式和姓名，如果需要进行设置，默认PKAddressFieldNone(没有送货地址)
    request.requiredShippingAddressFields = PKAddressFieldPostalAddress|PKAddressFieldPhone|PKAddressFieldName;
    
    // 设置配送方式
    PKShippingMethod *freeShip = [PKShippingMethod summaryItemWithLabel:@"包邮"
                                                                 amount:[NSDecimalNumber zero]];
    freeShip.identifier = @"freeShip";
    freeShip.detail = @"7天之内送达";
    
    PKShippingMethod *expressShip = [PKShippingMethod summaryItemWithLabel:@"快递"
                                                                    amount:[NSDecimalNumber decimalNumberWithString:@"10.00"]];
    expressShip.identifier = @"expressShip";
    expressShip.detail = @"当天送达";
    // shippingMethods为配送方式列表，类型是 NSMutableArray，这里设置成成员变量，在后续的代理回调中可以进行配送方式的调整。
    _shippingMethods = [NSMutableArray arrayWithArray:@[freeShip,expressShip]];
    request.shippingMethods = _shippingMethods;
    
    // 创建支付控制器
    PKPaymentAuthorizationViewController *payVC = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest:request];
    // 设置代理
    payVC.delegate = self;
    if (!payVC) {
        NSLog(@"出现问题");
        // 抛出一个异常
//        @throw [NSException exceptionWithName:@"CQ_Error" reason:@"创建控制器失败" userInfo:nil];
        return;
    }
    // 模态出支付界面
    [self presentViewController:payVC animated:YES completion:nil];
    
}

#pragma mark ----- 付款成功苹果服务器返回信息回调，做服务器验证
// payment 代表的是订单的支付信息，主要包含订单的地址，订单的token；completion 用这个block块可以用来指定界面上显示的支付结果
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                       didAuthorizePayment:(PKPayment *)payment
                                completion:(void (^)(PKPaymentAuthorizationStatus status))completion
{
    // 支付凭据，发给服务端进行验证支付是否真实有效
    PKPaymentToken *payToken = payment.token;
    NSLog(@"payToken:%@",payToken);
    // 账单信息
    PKContact *billingContact = payment.billingContact;
    NSLog(@"billingContact:%@",billingContact.postalAddress.city);
    // 送货信息
    PKContact *shippingContact = payment.shippingContact;
    NSLog(@"shippingContact:%@",shippingContact.postalAddress.street);
    // 配送方式
    PKShippingMethod *shippingMethod = payment.shippingMethod;
    NSLog(@"shippingMethod:%@",shippingMethod);
    
    // 将地址信息还有token信息发送到自己的服务器上，由自己的服务器返回结果
    // 等待服务器返回结果后再进行系统block调用
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 订单的返回结果 是个枚举值
        PKPaymentAuthorizationStatus status;
        // 接受从服务器的返回结果
        // PKPaymentAuthorizationStatusInvalidBillingPostalAddress 送货地址
        // PKPaymentAuthorizationStatusInvalidShippingContact 送货联系人
        // PKPaymentAuthorizationStatusPINRequired 输入的支付密码错误
        // PKPaymentAuthorizationStatusPINIncorrect 输入的支付密码错误
        // PKPaymentAuthorizationStatusPINLockout 以输入太多次错误的支付密码
        completion(status);
    });
}
// 送货信息回调
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                  didSelectShippingContact:(PKContact *)contact
                                completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKShippingMethod *> * _Nonnull, NSArray<PKPaymentSummaryItem *> * _Nonnull))completion{
    // contact送货地址信息，PKContact类型
    NSPersonNameComponents *name = contact.name;
    CNPostalAddress *postalAddress = contact.postalAddress;
    NSString *emailAddress = contact.emailAddress;
    CNPhoneNumber *phoneNumber = contact.phoneNumber;
    // 补充信息,iOS9.2及以上才有
    NSString *supplementarySubLocality = contact.supplementarySubLocality;
    
    // 送货信息选择回调，如果需要根据送货地址调整送货方式，比如普通地区包邮+极速配送，偏远地区只有付费普通配送，进行支付金额重新计算，可以实现该代理，返回给系统：shippingMethods配送方式，summaryItems账单列表，如果不支持该送货信息返回想要的PKPaymentAuthorizationStatus
    completion(PKPaymentAuthorizationStatusSuccess, _shippingMethods, _summaryItems);
}
// 配送方式回调
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                   didSelectShippingMethod:(PKShippingMethod *)shippingMethod
                                completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKPaymentSummaryItem *> * _Nonnull))completion{
    // 配送方式回调，如果需要根据不同的送货方式进行支付金额的调整，比如包邮和付费加速配送，可以实现该代理
    PKShippingMethod *oldShippingMethod = [_summaryItems objectAtIndex:2];
    PKPaymentSummaryItem *total = [_summaryItems lastObject];
    total.amount = [total.amount decimalNumberBySubtracting:oldShippingMethod.amount];
    total.amount = [total.amount decimalNumberByAdding:shippingMethod.amount];
    
    [_summaryItems replaceObjectAtIndex:2 withObject:shippingMethod];
    [_summaryItems replaceObjectAtIndex:3 withObject:total];
    
    completion(PKPaymentAuthorizationStatusSuccess, _summaryItems);
}

// 银行卡回调
-(void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didSelectPaymentMethod:(PKPaymentMethod *)paymentMethod completion:(void (^)(NSArray<PKPaymentSummaryItem *> * _Nonnull))completion{
    // 支付银行卡回调，如果需要根据不同的银行调整付费金额，可以实现该代理
    completion(_summaryItems);
}

#pragma mark ----- 支付完成
- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller
{
    [controller dismissViewControllerAnimated:YES completion:nil];
    NSLog(@"支付完成");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
