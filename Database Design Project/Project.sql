--Stored Procedures

--1) Retrieves total material shopping fee with particular company up to now, groups by materials
Create Procedure sp_MaterialPrice
@companyName nvarchar(50)
As
Begin

	Select i.companyName, i.materialName, sum(i.invoicePrice) TotalPaid 
	From Invoice i
	Where i.companyName=@companyName
	Group By i.companyName, i.materialName

End
--exec sp_MaterialPrice 'Yurdagül Hýrdavat'
---------------------------------------


--2) Takes departmentName and buildingSiteCode as parameters and retrieves 
--employee's departmentID, employeeID, number of workers who works that building site, 
--manager of that building site, and the total payment of that departments workers on that building site
Create Procedure sp_depInfo
@departmentName nvarchar(50),
@buildingSiteCode nvarchar(50)
As
Begin

Select wd.departmentID, wd.departmentName, wbs.buildingSiteCode, count(w.empID) NoOfWorker, e.fName + ' ' + e.lName ManagerName, e.empID, sum(workersalary.WorkerSalary)TotalPay
From Worker w, WorkerDepartment wd, Employee e, Worker_BuildingSite wbs, (Select sum(wbs.hourlyFee*workingHour*26)WorkerSalary 
																		  From Worker_BuildingSite wbs 
																					  inner join Worker w on wbs.workerID=w.empID 
																					  inner join WorkerDepartment wd on wd.departmentID=w.departmentID 
																		  Where wd.departmentName=@departmentName and wbs.buildingSiteCode=@buildingSiteCode) workersalary
Where w.departmentID=wd.departmentID and wd.managerID=e.empID and wd.departmentName=@departmentName and wbs.workerID=w.empID and wbs.buildingSiteCode=@buildingSiteCode
Group By wd.departmentID, wd.departmentName, e.fName + ' ' + e.lName, e.empID, wbs.buildingSiteCode

End

--exec sp_depInfo 'Blacksmith', 'IST1002'
----------------------------------------
--3) Retrieves the addresses of buyers who buy apartments under a certain price
Create Procedure sp_BuyerAddress
@price decimal(20,2)
As
Begin
	Select b.city + ' ' + b.street Address
	From Contract c inner join Buyer b on c.TCKN=b.TCKN 
	Where c.buyPrice <= @price 
	Order By b.city asc
End
--exec sp_BuyerAddress 500000
----------------------------------------
--4) It gives a 10 percent raise to workers working at building sites with a delay due to a walkout,
-- and a 5 percent raise to workers working at building sites with a delay due yo a salary issue.
Create Procedure sp_UpdateWorkerHourlyFee
@delayReason nvarchar(100)
As
Begin
	
	If @delayReason='Walkout'
	Begin
		Update Worker_BuildingSite
		Set hourlyFee=hourlyFee*1.10
		From Worker_BuildingSite wbs inner join Delay d on wbs.buildingSiteCode=d.buildingSiteCode
		Where d.delayReason=@delayReason
	End

	If @delayReason='Salary Issue'
	Begin
		Update Worker_BuildingSite
		Set hourlyFee=hourlyFee*1.05
		From Worker_BuildingSite wbs inner join Delay d on wbs.buildingSiteCode=d.buildingSiteCode
		Where d.delayReason=@delayReason
	End

End
--exec sp_UpdateWorkerHourlyFee 'Walkout'
--Select wbs.workerID, wbs.hourlyFee From Worker_BuildingSite wbs inner join Delay d on wbs.buildingSiteCode=d.buildingSiteCode Where d.delayReason='Walkout'
-----------------------------------------
--5)In the selected department, it increases the salary of the employees within a certain age range by the desired amount.
Create Procedure sp_UpdateSalaryByAge
  @empType varchar(50),
  @age1 int,
  @age2 int,
  @raisePercent float
 As
 Begin
	
	If(@empType='OfficeWorker')
	Begin
	Update OfficeWorker
	Set Salary += ow.salary * @raisePercent / 100
	From OfficeWorker ow inner join Employee e on ow.empID=e.empID 
	Where e.age >= @age1 and e.age <= @age2
	End

	If(@empType='Technician')
	Begin
	Update Technician
	Set Salary += t.salary * @raisePercent / 100
	From Technician t inner join Employee e on t.empID=e.empID 
	Where e.age >= @age1 and e.age <= @age2
	End

	If(@empType='WhiteCollar')
	Begin
	Update WhiteCollar
	Set Salary += wc.salary * @raisePercent / 100
	From WhiteCollar wc inner join Employee e on wc.empID=e.empID 
	Where e.age >= @age1 and e.age <= @age2
	End

	If(@empType='Worker')
	Begin
	Update Worker_BuildingSite
	Set hourlyFee += wbs.hourlyFee * @raisePercent / 100
	From Worker_BuildingSite wbs inner join Employee e on wbs.workerID=e.empID 
	Where e.age >= @age1 and e.age <= @age2
	End
 End
 --exec sp_UpdateSalaryByAge 'OfficeWorker', 36, 41, 3
 --Select ow.empID, ow.salary From OfficeWorker ow inner join Employee e on ow.empID=e.empID Where e.age>=36 and e.age<=41
 --------------------------------------------------
 --6) Calculates the total overpaid salary due to the extension of the building site duration
 -- at the building sites with delay.
Create Procedure sp_ExtraPaymentDueToDelay
  @buildingSiteCode nvarchar(50)
 As
 Begin	
	Select sum(wbs.hourlyFee*wbs.workingHour*d.delayTime*26) as ExtraPayment
	From BuildingSite bs inner join Delay d on bs.buildingSiteCode=d.buildingSiteCode
		 inner join Worker_BuildingSite wbs on bs.buildingSiteCode=wbs.buildingSiteCode
	Where bs.buildingSiteCode=@buildingSiteCode
 End
 exec sp_ExtraPaymentDueToDelay 'IST1003'
 ---------------------------------------------------
--7)Takes a location as parameter and returns the number of
--apartments sold which resides in that location
Create Procedure sp_getNumOfSoldApsbyLocation
(@location nvarchar(100))
as
begin
    Select c.buildingID, bs.location, COUNT(*) #ofSoldApartments
    From Contract c inner join Buyer b on c.TCKN = b.TCKN
    inner join Building bl on bl.buildingID = c.buildingID
    inner join BuildingSite bs on bs.buildingSiteCode = bl.buildingSiteCode
    Where bs.location like '%' + @location + '%'
    Group By c.buildingID, bs.location
end
--exec sp_getNumOfSoldApsbyLocation 'ankara'
---------------------------------------------------------------
--8)Retrieves Employee Id, name, surname and email of the workers 
--which works on building sites that has less than the delay passed
--as the argument
Create Procedure sp_getWorkersBuildingSiteByDelay
(@delay int)
As 
Begin 
    Select distinct w.empID, e.fName + ' ' +  e.lName FullName, e.email
    From Worker w
    inner join Worker_BuildingSite wb on w.empID = wb.workerID
    inner join BuildingSite bs on wb.buildingSiteCode = bs.buildingSiteCode
    inner join Employee e on w.empID = e.empID
    Where bs.buildingSiteCode in (Select bs.buildingSiteCode
                                    From BuildingSite bs 
                                    inner join Delay d on bs.buildingSiteCode = d.buildingSiteCode 
                                    Group by bs.buildingSiteCode
                                    Having SUM(d.delayTime) < @delay) 
End
--exec sp_getWorkersBuildingSiteByDelay 3
------------------------------------------------------------------------------------
--9)Retrieve full name of buyers that live in the same location with building site location
Create Proc sp_BuyersThatLivesInSameLoc
(@location varchar(50))
As
Begin

Select b.fName + ' ' + b.lName as FullName, bs.buildingSiteCode, bs.location
From Buyer b 
inner join Contract c ON b.TCKN = c.TCKN
Inner join Building bu ON c.buildingID = bu.buildingID
Inner join BuildingSite bs ON bu.buildingSiteCode = bs.buildingSiteCode
Where bs.location like  '%' + @location + '%'

End

--exec sp_BuyersThatLivesInSameLoc 'ankara'
-----------------------------------------------------------------------------
--10) Update employee
Create Proc sp_UpdateEmployee(

    @empID int,
    @fName nvarchar(50),
    @lName nvarchar(50),
    @birthDate date,
    @gender char(1),
    @startDate date,
    @email nvarchar(100),
    @employeeType varchar(50),
    @managerID int
)
As 
Begin

    Update Employee
    Set fName = @fName, lName = @lName, birthDate = @birthDate, gender = @gender,
    startDate = @startDate, email = @email, employeeType = @employeeType
    Where empID = @empID and managerID = @managerID

End

--exec sp_UpdateEmployee 433, 'Murat', 'Çelik', '1990-10-19', 'F', '2017-12-19', 'mcelik@outlook.com', 'Worker',101
--Select * From Employee e Where e.empID=433

--Queries

--1) Retrieves the empID, first name, last name, salary, and the number of sells of manager who are the top 3 best seller
Select Top 3 e.empID ,e.fName, e.lName, wc.salary, count(bs.managerID)topSeller
From BuildingSite bs inner join Employee e on bs.managerID = e.empID
	 inner join WhiteCollar wc on e.empID = wc.empID
Group by e.empID, e.fName, e.lName, wc.salary
Order By topSeller desc
--------------------------------------------
--2
Select e.officeID, (e.shortTermPrice + e.longtermprice + e.whitecollarprice + e.officeworkerprice) totalMonthlyPrice
From (Select o.officeID, SUM(so.price/st.leasingTerm) shortTermPrice, SUM(lt.monthlyWage) longtermprice, SUM(wc.salary) whitecollarprice, SUM(ow.salary) officeworkerprice
From Office o 
        inner join ShortTerm_Office so on o.officeID = so.officeID
        inner join ShortTerm st on st.companyName = so.companyName
        inner join LongTerm_Office lo on lo.officeID = o.officeID
        inner join LongTerm lt on lo.companyName = lt.companyName
        inner join WhiteCollar_Office wo on o.officeID  = wo.officeID
        inner join WhiteCollar wc on wc.empID = wo.empID
        inner join OfficeWorker_Office oo on oo.officeID = o.officeID
        inner join OfficeWorker ow on ow.empID = oo.officeWorkerID
        Group By o.officeID) e
Order By totalMonthlyPrice desc
-------------------------------------------------------
--3) Retrieves building site code, total earned money, building site cost, and percentage of profit of building sites that completed
Select f.buildingSiteCode ,f.earnedMoney, f.buildingSiteCost ,(f.earnedMoney - f.buildingSiteCost) / f.buildingSiteCost * 100 '%Profit'
From(Select bs.buildingSiteCode, SUM(i.invoicePrice) buildingSiteCost, SUM(c.buyPrice) earnedMoney
From BuildingSite bs inner join Invoice i on bs.buildingSiteCode = i.buildingSiteCode
inner join Building b on bs.buildingSiteCode = b.buildingSiteCode 
inner join Contract c on b.buildingID = c.buildingID
Group By bs.buildingSiteCode) f
----------------------------------------------------
--4) Retrieves department name and average age of workers for every worker department
Select wd.departmentName, avg(e.age * 1.0) AvgAgeOfWorkers
From Worker w inner join Employee e On w.empID = e.empID
inner join WorkerDepartment wd On w.departmentID = wd.departmentID
Group By wd.departmentName
------------------------------------------------------
--5) Retrieves building site code, construction time and construction cost of every building site that completed
Select distinct bs.buildingSiteCode, Concat(Datediff(Day, bs.startDate, bs.endDate) , ' Day') as ConstructionTime, Sum(i.invoicePrice) ConstructionCost
From BuildingSite bs inner join Invoice i ON bs.buildingSiteCode = i.buildingSiteCode
Group by bs.buildingSiteCode, bs.startDate, bs.endDate
Having bs.endDate is not null
Order by ConstructionTime Desc
------------------------------------------------------
--6) Retrieve name, surname, salary, numberof degrees and supervisor name of all white collar employees which have at least 2 degrees
--by ordering according to degrees increasing and salaries decreasing
Select q.fullName, q.#ofDegrees, q.salary, m.fName + ' ' + m.lName SupervisorName
From (
    Select e.fName + ' ' + e.lName fullName,COUNT(*) #ofDegrees, w.salary,  w.supervisorID
    From WhiteCollar w
    inner join WhiteCollarDegree wd on w.empID = wd.empID
    inner join Employee e on e.empID = wd.empID 
    Group By w.empID, e.fName, e.lName, w.supervisorID, w.salary
    Having COUNT(*) >= 2) q
inner join Employee m on q.supervisorID = m.empID
Order By q.#ofDegrees desc, q.salary desc

--Triggers

--If an employee data is added or removed, it writes the transaction type, 
--empID and employee name in the log message of the log table
Create Trigger trg_Log
  on Employee
  after insert
As
Begin
	IF exists (Select * From inserted)
	Begin
	Insert Into LogTable(LogMessage) 
	Select('New employee hired : ' + CONVERT(nvarchar(50), insertedEmp.empID) + ' ' + insertedEmp.EmpName)
	From  (Select e.empID, e.fName + ' ' + e.lName EmpName
		   From Employee e, inserted i
		   Where e.empID = i.empID) insertedEmp
	End
	
	IF exists (Select * From deleted)
	Begin
	Insert Into LogTable(LogMessage) 
	Select('An employee fired : ' + CONVERT(nvarchar(50), deletedEmp.empID) + ' ' + deletedEmp.EmpName)
	From  (Select e.empID, e.fName + ' ' + e.lName EmpName
		   From Employee e, deleted d
		   Where e.empID = d.empID) deletedEmp
	End
End

--Insert Into Employee(empID, fName, lName, birthDate, gender, startDate, employeeType, managerID)
--Values(192, 'Mustafa', 'Aðaoðlu', '1985-07-19' , 'M', '2020-12-21', 'WhiteCollar', 101)
--Select * From LogTable
--------------------------------------------------------------


