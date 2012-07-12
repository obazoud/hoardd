Name:           hoardd
Version:        0.1.1
Release:        1%{?dist}
Summary:        Hoardd is extensible daemon designed to collect server data and inject into Graphite/Carbon
Group:          Applications/Internet
License:        GPL
URL:            https://github.com/jlambert121/hoardd
Vendor:         jlambert
Packager:       Justin Lambert <jlambert@eml.cc>
Source0:        %{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch

Requires:       nodejs

%description
Collect server statistics and send to graphite

%prep
%setup -q

%build

%install
# install the js files which do the work
#%{__mkdir_p} %{buildroot}/usr/share/%{name}/scripts
%{__mkdir_p} %{buildroot}%{_sysconfdir}/%{name}/scripts
%{__install} -Dp -m0644 start.js %{buildroot}/usr/share/%{name}/hoardd.js
%{__install} -Dp -m0644 src/sender.coffee src/server.coffee src/start.coffee %{buildroot}/usr/share/%{name}
%{__install} -Dp -m0755 init/%{name} %{buildroot}%{_initrddir}/%{name}
%{__install} -Dp -m0644 config.json.example  %{buildroot}%{_sysconfdir}/%{name}/config.js
%{__install} -Dp -m0644 scripts/*.coffee %{buildroot}%{_sysconfdir}/%{name}/scripts
%{__mkdir_p} %{buildroot}%{_localstatedir}/lock/subsys
touch %{buildroot}%{_localstatedir}/lock/subsys/%{name}
%{__mkdir_p} %{buildroot}/usr/share/%{name}/node_modules
cd %{buildroot}/usr/share/%{name}
npm install cli
npm install coffee-script
npm install graphite
sed -i 's,/full/path/to/scripts/dir,%{_sysconfdir}/%{name}/scripts,g' %{buildroot}%{_sysconfdir}/%{name}/config.js
sed -i 's,/src/start,/start,g' %{buildroot}/usr/share/%{name}/hoardd.js

%preun
service %{name} stop
exit 0

%postun
if [ $1 = 0 ]; then
	chkconfig --del %{name}
fi
exit 0

%post
chkconfig --add %{name}

#%clean
#[ "%{buildroot}" != "/" ] && %{__rm} -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc LICENSE README.md
%doc config.json.example
%doc scripts-available/*.coffee

/usr/share/%{name}/*
%{_sysconfdir}/%{name}/*
%{_initrddir}/%{name}

%ghost %{_localstatedir}/lock/subsys/%{name}

%changelog
* Thu Jul 12 2012 Justin Lambert <jlambert@eml.cc> 0.1.0-1
- Initial spec file - version 0.1.0-1
