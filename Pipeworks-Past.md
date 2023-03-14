## Pipeworks's Past

Pipeworks was created in 2011 as one of the first PowerShell web frameworks.

It's goal is reducing the time and effort required to turn any PowerShell module into Software as a Service.

As there were few options available at the time, this required the creation of a quite frankly ludicrous amount of direct hosting of PowerShell and, thus, templating of other languages.  It also involved working with very early versions of cloud services like Azure and Amazon Web Services.

This resulted in a few big problems and one happy/unhappy accident

* A _Big_ Module, with many commands you might never use
* Web development was a very rapidly changing place
* A lot more strong coupling than expected

The happy accident was that, in allowing for local websites to be build atop PowerShell, Pipeworks made _a lot_ of Intranet sites.

This let Pipeworks grow privately for number of years, and build lots of websites the wider world will never see.

Meanwhile, web development overall began a series of breaking changes and cataclysmic shifts.

The first generations of cloud services gave way to the second, and this broke parts of Pipeworks.

This led us to the the conclusion that Pipeworks was too dense as-is, and needed to be broken down, back up and rebuilt with the assistance of a new ecosystem of tools.