requires "Class::Null" => "2.110730";
requires "Date::Format" => "2.24";
requires "Exporter::Tiny" => "0.042";
requires "File::DataClass" => "v0.66.0";
requires "IPC::ShareLite" => "0.17";
requires "Moo" => "2.000001";
requires "Time::Elapsed" => "0.31";
requires "Try::Tiny" => "0.22";
requires "Type::Tiny" => "1.000004";
requires "Unexpected" => "v0.39.0";
requires "namespace::autoclean" => "0.26";
requires "perl" => "5.010001";
recommends "Cache::Memcached" => "1.30";

on 'build' => sub {
  requires "Module::Build" => "0.4202";
  requires "version" => "0.88";
};

on 'test' => sub {
  requires "File::DataClass" => "v0.66.0";
  requires "Module::Build" => "0.4202";
  requires "Test::Requires" => "0.06";
  requires "version" => "0.88";
};

on 'configure' => sub {
  requires "Module::Build" => "0.4202";
  requires "version" => "0.88";
};
