library clisitef;

enum TipoPinPad {
  nenhum('NENHUM'),
  auto('ANDROID_AUTO'),
  usb('ANDROID_USB'),
  bluetooth('ANDROID_BT'),
  apos('ANDROID_APOS'),
  ingenico('ANDROID_INGENICORUA');

  const TipoPinPad(this.value);
  final String value;
}
