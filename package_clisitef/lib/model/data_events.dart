enum DataEvents {
  unknown,
  data,
  messageCashier,
  messageCustomer,
  messageCashierCustomer,
  menuTitle,
  headerShow,
  confirmGoBack,
  confirmation,
  menuOptions,
  pressAnyKey,
  abortRequest,
  getFieldInternal,
  getField,
  getFieldCheque,
  getFieldTrack,
  getFieldPassword,
  getFieldBarCode,
  getFieldCurrency,
  getPinPadConfirmation,
  getMaskedField,
  showQrCodeField,
  removeQrCodeField,
  messageQrCode,
}

extension DataEventsString on String {
  DataEvents get dataEvent {
    switch (this) {
      case 'DATA':
        return DataEvents.data;
      case 'MESSAGE_CASHIER':
        return DataEvents.messageCashier;
      case 'MESSAGE_CUSTOMER':
        return DataEvents.messageCustomer;
      case 'MESSAGE_CASHIER_CUSTOMER':
        return DataEvents.messageCashierCustomer;
      case 'MENU_TITLE':
        return DataEvents.menuTitle;
      case 'HEADER_SHOW':
        return DataEvents.headerShow;
      case 'CONFIRM_GO_BACK':
        return DataEvents.confirmGoBack;
      case 'CONFIRMATION':
        return DataEvents.confirmation;
      case 'MENU_OPTIONS':
        return DataEvents.menuOptions;
      case 'PRESS_ANY_KEY':
        return DataEvents.pressAnyKey;
      case 'ABORT_REQUEST':
        return DataEvents.abortRequest;
      case 'GET_FIELD_INTERNAL':
        return DataEvents.getField;
      case 'GET_FIELD':
        return DataEvents.getFieldInternal;
      case 'GET_FIELD_CHEQUE':
        return DataEvents.getFieldCheque;
      case 'GET_FIELD_TRACK':
        return DataEvents.getFieldTrack;
      case 'GET_FIELD_PASSWORD':
        return DataEvents.getFieldPassword;
      case 'GET_FIELD_BARCODE':
        return DataEvents.getFieldBarCode;
      case 'GET_FIELD_CURRENCY':
        return DataEvents.getFieldCurrency;
      case 'GET_PINPAD_CONFIRMATION':
        return DataEvents.getPinPadConfirmation;
      case 'GET_MASKED_FIELD':
        return DataEvents.getMaskedField;
      case 'SHOW_QRCODE_FIELD':
        return DataEvents.showQrCodeField;
      case 'REMOVE_QRCODE_FIELD':
        return DataEvents.removeQrCodeField;
      case 'MESSAGE_QRCODE':
        return DataEvents.messageQrCode;
    }
    return DataEvents.unknown;
  }
}
