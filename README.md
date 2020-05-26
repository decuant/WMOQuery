#  **WMOQuery**

## Project description - rel. 0.0.1 (20-May-2020)

**WMOQuery** is a set of tiny scripts for monitoring weather world wide and retrieve statistics on it. Only forecast temperatures can be analyzed because climate values are shipped as aggregates over a year course and they are not updated by stations anymore.

Datasets are collected daily from the World Meteorology Organization, whose Internet home address is 
  https://worldweather.wmo.int/en/home.html .

Some stations provide 1 reading a day, some 2; the number of days in a forecast table are station dependent and range from 3 to 9; some stations provide less days than usual for weekends (possibly in bank holidays too). There might be missing values, usually the very first value for minimum temperature, a fixture for some (London), at random for others (Washington DC). Under developed countries or war zones don't provide updates at all (Afghanistan and Mexico are an example).

Mainly aimed at meteorologists and scientists, code has been written in the most simple way and commented where necessary, thinking that it is a starting point for tailoring or as source of new ideas, aimed at engineers with little practice of programming.

The project uses Lua as programming language and benefits of some external libraries. It was developed on Windows 10 and should be easily used on Unix provided some necessary modifications.  With this in mind code can possibly be an example of using wxWidgets with Lua, both for GUI and facilities. The IDE of choice is ``ZeroBrane``.

Binaries for Lua and wxWidgets (64 bits for Windows) can be found here: https://github.com/decuant/wxLua535Win10

The ZeroBrane installer (a multi-platform Lua IDE) can be found here: https://studio.zerobrane.com/

serpent (Lua serialize) can be found here: https://github.com/pkulchenko/serpent

json4lua (JSon decoder for Lua) can be found here: https://github.com/craigmj/json4lua

Reading [The Evolution of Lua](https://www.lua.org/doc/hopl.pdf) might make you adopt Lua as your programming language of choice.

## Installation

Cloning the project will get you a folders' structure like this:

```
WMOQuery                                (root)
  |--config
  |--data
     |--2020                            (archive - year)
        |--05                                      month
           |--20                                   day
              |--08-00                             hh-mm
              |--23-00
     |--region
     |--SAT
     |--update                          (last downloaded dataset)
  |--docs
  |--lib
     |--icons
  |--log                                (trace)
```

Folders' structure is indicative, especially regarding data, since it might be useful to have the archive in an external backed-up drive. Source code is in the ``root`` and ``lib`` folders, whilst configuration files are in ``config``; all files in these 3 folders are Lua code, divided this way to keep the project clean.

File formats:

```
.lua                  (code and configuration)
.json            (downloaded dataset)
.dat        (compiled dataset)
.log   (trace of execution)
```

## Modules

Here the list of modules that can be launched at command prompt, all of which are in the ``root`` folder, sub-modules are their own configuration files (as said they reside in the ``config`` folder) :

```
  .1 download
      --favorites
  .2 archive
      --folders
  .3 schedule
      --automatic
  .4 view
  .5 console
      --preferences
  .6 compile
```

# .1 download

Executes the download of 1 or more datasets from the WMO' site. Uses the GET command of the HTTP protocol version 1.1 to retrieve a single ``json`` file. A list of favorite files can be supplied in ``favorites.lua``, so that the command will actually batch download. See the comments in the source, you'll have to pass an extra argument ``--favorites`` on the command line. Otherwise you can specify a ``remote filename`` and ``local filename`` to download anything else (like if you want to download the ``regions.json`` or ``SAT.txt``). Have a look in the ``doc`` folder for the complete list of all the available stations in the world.


# .2 archive

Copies datasets from the ``update`` folder to the archive folder, structuring it with the current date and time. An option in its configuration file ``folders.lua`` allows to use the modification date of the file with the most recent date-time in the set. This option might be useful or not, depends where updates are stored, in fact when downloads use the same target folders new files will overwrite older ones.



# .3 schedule

General replacement for Tasks in Windows or cron in Unix, with the benefit of being Lua code and running Lua functions. It must be executed automatically at the O.S. startup.



# .4 view

GUI for viewing a dataset in tabular format.



# .5 console

GUI interface for launching a script or to plot 1 or more dataset(s).

This is an example from the ``WMO Samples.dat`` that I left in the ``archived`` folder

![Madrid Archived](/docs/Madrid_Archived.png)


# .6 compile

This is an internal script to collect forecast data from the archive folder and used by the plot function in ``console``. Given a start (root) directory it will inspect any sub-folder searching for ``json`` file extension. It does parse each file and build a table of stations, for each station will build a sub-table collecting data using the issue date. Thus the user can collect data only for a specific day/month/year only specifying the root directory of interest. The file contains all stations found. Note that fields ``id`` and ``city_name`` do represent the same station, it is useful though for display on screen. When an ``issue date`` for a station is already compiled it won't be collected again or overwrite the previous one and as such the first issue date found is treated as the valid one.

File format:

```
{ id, city_name, {  { issue_date, { {date, min, max}, {date, min, max}, ... } },
					{ issue_date, { {date, min, max}, {date, min, max}, ... } },
					...
				 },
},

{ id, city_name, ...
},

```




## A final word

I used [``Sublime Text``](https://www.sublimetext.com/) for writing this document, with spell check enabled. To validate the layout on a web page I used to copy and paste text into the live editor available at [``Dillinger``](https://dillinger.io/).

I use [``SumatraPDF``](https://www.sumatrapdfreader.org/free-pdf-reader.html) for reading PDF files. I can have white text on a black background and have a single application for reading multiple documents formats that otherwise would require me more applications, like ``chm``, ``mobi``, ``epub`` and the like.

## Author

The author can be reached at decuant@gmail.com


## License

The standard MIT license applies.
