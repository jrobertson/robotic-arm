Gem::Specification.new do |s|
  s.name = 'robotic-arm'
  s.version = '0.2.3'
  s.summary = 'robotic-arm'
  s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_dependency('libusb') 
  s.signing_key = '../privatekeys/robotic-arm.pem'
  s.cert_chain  = ['gem-public_cert.pem']
end
