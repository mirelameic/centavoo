import { createBrowserRouter } from 'react-router-dom';
import { App } from './App';
import { Trips } from './pages/Trips';
import { Trip } from './pages/Trip';

export const router = createBrowserRouter([
  {
    path: '/',
    element: <App />,
    children: [
      { index: true, element: <Trips /> },
      { path: 'trip/:id', element: <Trip /> },
    ],
  },
]);
