task default: %w(debug)


directory "certs"
file "certs/ca-key.pem"  => :makeca
file "certs/ca-cert.pem" => :makeca
task :makeca => ["certs"] do
  sh <<END
openssl req -new -newkey rsa:2048 -days 3650 -nodes \
  -x509 \
  -keyout certs/ca-key.pem \
  -out certs/ca-cert.pem \
  -subj /CN=binproxy-ca
END
end

task :makecert => ["certs/ca-cert.pem","certs/ca-key.pem"]
task :makecert, [:host] do |t, opts|
  host = opts[:host]
  sh <<END
openssl req -new -newkey rsa:2048 -days 3650 -nodes \
  -keyout certs/#{host}-key.pem \
  -subj "/CN=#{host}" \
| openssl x509 -req -days 3650 \
  -CA certs/ca-cert.pem \
  -CAkey certs/ca-key.pem \
  -CAcreateserial \
  -CAserial certs/ca-serial \
  -out certs/#{host}-cert.pem
END
end

task :debug do
  sh "./run.sh -D -c DumbHttp::Message 127.0.0.1 8001 127.0.0.1 8000"
end

task :'debug-socks' do
  sh "./run.sh -DS -c DumbHttp::Message localhost 1080"
end

task :spec do
  sh "bundle exec rspec spec"
end

task :'build-ui' do
  sh "cp ui/node_modules/fixed-data-table/dist/fixed-data-table.css public/ui/fixed-data-table.css"
  sh "cd ui; ./node_modules/webpack/bin/webpack.js"
end

task :'rerun-build-ui' do
  sh "cp ui/node_modules/fixed-data-table/dist/fixed-data-table.css public/ui/fixed-data-table.css"
  sh "rerun -d ui/src/ -p '*.js*' -x -b rake build-ui"
end
