enum RustNetMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  patch('PATCH'),
  delete('DELETE'),
  head('HEAD'),
  options('OPTIONS');

  const RustNetMethod(this.wireValue);

  final String wireValue;
}
