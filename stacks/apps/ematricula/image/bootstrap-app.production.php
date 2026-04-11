<?php

use App\Http\Middleware\ForceJsonResponse;
use App\Modules\Acl\Http\Middleware\EnsureUserHasPermission;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->redirectGuestsTo(function (Request $request) {
            if ($request->is('api/*') || $request->expectsJson()) {
                return null;
            }

            return Route::has('login') ? route('login') : null;
        });
        $middleware->appendToGroup('api', ForceJsonResponse::class);
        $middleware->alias([
            'permission' => EnsureUserHasPermission::class,
        ]);
    })
    ->withSchedule(function (Schedule $schedule): void {
        $schedule->command('billing:generate-recurring-invoices')->dailyAt('01:00');
        $schedule->command('payments:sync-invoice-statuses')->everyFiveMinutes()->withoutOverlapping();
        $schedule->command('invoices:send-due-reminders')->dailyAt('08:00')->withoutOverlapping();
        $schedule->command('invoices:send-overdue-reminders')->dailyAt('09:00')->withoutOverlapping();
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        //
    })->create();
