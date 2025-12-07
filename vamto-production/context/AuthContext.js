
import { createContext, useContext, useEffect, useState } from 'react';

const AuthContext = createContext({ user: null, loading: true, setUser: ()=>{} });

export const AuthProvider = ({ children }) => {

  const [user, setUser] = useState(null);

  const [loading, setLoading] = useState(true);

  useEffect(() => {

    let mounted = true;

    fetch('/api/me')

      .then(r => r.json())

      .then(j => {

        if (!mounted) return;

        setUser(j.user || null);

      })

      .catch(() => setUser(null))

      .finally(() => mounted && setLoading(false));

    return () => { mounted = false; };

  }, []);

  return (

    <AuthContext.Provider value={{ user, setUser, loading }}>

      {children}

    </AuthContext.Provider>

  );

};

export const useAuth = () => useContext(AuthContext);

