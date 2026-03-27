enum NexaHttpMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  patch('PATCH'),
  delete('DELETE'),
  head('HEAD'),
  options('OPTIONS');

  const NexaHttpMethod(this.wireValue);

  final String wireValue;
}
