# Historical Version For Reference Only

This branch is not connected to any branches in the official icu repository, it pre-dated the icu projects move to github.
The current (as of 18-Feb-2022) branch is named fw and it will be frequently be updated to track icu releases.

# Icu4c

**NOTE:** See the original project's readme at [readme.html](https://github.com/sillsdev/icu4c/blob/FieldWorks/readme.html)

This project is a mirror of the svn project at <http://source.icu-project.org/repos/icu/icu/> (see [icu-project.org](http://icu-project.org)).

## Special long-lived branches

### Fieldworks

Based on the 54.1 release tag, this branch contains some specific changes for the [Fieldworks project](https://github.com/sillsdev/fieldworks)

### MinimumStaticallyLinked*

These branches are based on -- but have two major differences from -- the 54.1 or whatever release tags:

- It is a "minimum" build as described [here](https://github.com/sillsdev/icu-dotnet#windows-1)
- It is statically linked to remove the dependency on the C++ Redistributable
  - This is accomplished by setting the runtime library in each .vcxproj file to MultiThreaded rather than MultiThreadedDLL

### FullStaticallyLinked*

These branches are based on -- but have one major differences from -- the 54.1 or whatever release tags:

- It is statically linked to remove the dependency on the C++ Redistributable
  - This is accomplished by setting the runtime library in each .vcxproj file to MultiThreaded rather than MultiThreadedDLL
