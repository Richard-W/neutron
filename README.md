Neutron
=======

A library for developing web-applications using the GObject-System.

Installation instructions
-------------------------

<dl>
<dt>Debian</dt>
<dd>
Inside the source-directory:
```bash
./configure --prefix=/usr --enable-debian
make
make package
```
Now you have a .deb-file, which you can install using "dpkg -i"
</dd>
<dt>Arch</dt>
<dd>
If you did not do it already install yaourt. Instructions for installing yaourt
can be found here: https://wiki.archlinux.de/title/Yaourt.
Now you can just install the package "neutron-git" from AUR.
</dd>
<dt>Ubuntu</dt>
<dd>
Just like Debian. Note that i have not tested anything on Ubuntu.
</dd>

Usage
-----

You will find some vala-files (among a few others) in the examples-directory. They are automatically build to build-dir/examples
if you specify --enable-examples and should give you a basic overview of the capabilities of this library.

The API is in absolutely no way stable. Expect major/breaking changes to it. I will stabilize it
eventually (release 0.2), but not until i am sure, that it is suitable for being the core of big projects. Every kind
of feedback is therefore appreciated.

I am trying to comment everything that might be relevant in valadoc-format. To get up-to-date documentation just run valadoc
over all the files in src/.

Info
----

This project was hosted on github. However as of now github is only used an a mirror. The main repository is https://git.metanoise.net/neutron
