Gem::Specification.new do |s|
  s.name = 'robotic-arm'
  s.version = '0.2.4'
  s.summary = 'robotic-arm'
  s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_dependency('libusb') 
  s.signing_key = '../privatekeys/robotic-arm.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/robotic-arm'
end
