enum AdapterType {
  adapterTypeUnknown,
  adapterTypeEthernet,
  adapterTypeWifi,
  adapterTypeCellular,
  adapterTypeVpn,
  adapterTypeLoopback,
  adapterTypeAny
}

extension AdapterTypeExt on AdapterType {
  String get value => name;
}
